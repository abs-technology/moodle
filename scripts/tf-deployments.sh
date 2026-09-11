#!/usr/bin/env bash
# Scaffold and list Terraform deployments. One directory per customer site, each
# with its own state object, so no apply can reach another customer's stack.
#
#   scripts/tf-deployments.sh new horizonschool-aws aws
#   scripts/tf-deployments.sh list
set -Eeuo pipefail

cd "$(dirname "$(readlink -f "$0")")/.."

GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'; RED=$'\033[0;31m'; NC=$'\033[0m'
info() { printf '%s==>%s %s\n' "$GREEN" "$NC" "$*"; }
warn() { printf '%s[!]%s %s\n' "$YELLOW" "$NC" "$*" >&2; }
die()  { printf '%s[x]%s %s\n' "$RED" "$NC" "$*" >&2; exit 1; }

# Where every deployment's state object lives. Override per shell if you keep
# state somewhere else.
: "${TF_STATE_BUCKET_AWS:=absi-moodle-tfstate}"
: "${TF_STATE_REGION:=ap-southeast-1}"
: "${TF_STATE_PROFILE:=default}"
: "${TF_STATE_BUCKET_GCP:=absi-moodle-tfstate}"
: "${TF_STATE_PROJECT_GCP:=}"

DEPLOYMENTS=terraform/deployments

cmd_list() {
    [[ -d "$DEPLOYMENTS" ]] || { echo "Chưa có deployment nào."; return 0; }

    printf '%-26s %-6s %-16s %s\n' DEPLOYMENT CLOUD IP DOMAIN
    local dir name cloud ip domain
    for dir in "$DEPLOYMENTS"/*/; do
        [[ -d "$dir" ]] || continue
        name="$(basename "$dir")"

        cloud=unknown
        grep -q 'modules/moodle-aws' "$dir/main.tf" 2>/dev/null && cloud=aws
        grep -q 'modules/moodle-gcp' "$dir/main.tf" 2>/dev/null && cloud=gcp

        ip="$(terraform -chdir="$dir" output -raw public_ip 2>/dev/null || echo -)"

        # tfvars first: change-domain.sh moves the live domain on the VM, and the
        # only record of that on this side is whoever updated moodle_domain.
        domain="$(sed -n 's/^ *moodle_domain *= *"\(.*\)"/\1/p' "$dir/terraform.tfvars" 2>/dev/null | head -1)"
        [[ -n "$domain" ]] || domain="$(terraform -chdir="$dir" output -raw site_url 2>/dev/null | sed 's|^https://||' || true)"
        [[ -n "$domain" ]] || domain=-

        printf '%-26s %-6s %-16s %s\n' "$name" "$cloud" "$ip" "$domain"
    done
}

ensure_bucket_aws() {
    local bucket="$1"
    if aws s3api head-bucket --bucket "$bucket" --profile "$TF_STATE_PROFILE" 2>/dev/null; then
        return 0
    fi

    info "Tạo bucket state s3://$bucket"
    aws s3api create-bucket --bucket "$bucket" --profile "$TF_STATE_PROFILE" \
        --region "$TF_STATE_REGION" \
        --create-bucket-configuration "LocationConstraint=$TF_STATE_REGION" >/dev/null

    # State holds the generated Moodle and MariaDB passwords in plaintext.
    aws s3api put-public-access-block --bucket "$bucket" --profile "$TF_STATE_PROFILE" \
        --public-access-block-configuration \
        'BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true'
    aws s3api put-bucket-encryption --bucket "$bucket" --profile "$TF_STATE_PROFILE" \
        --server-side-encryption-configuration \
        '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
    # Versioning is what turns a corrupted or truncated state into a rollback.
    aws s3api put-bucket-versioning --bucket "$bucket" --profile "$TF_STATE_PROFILE" \
        --versioning-configuration Status=Enabled
}

ensure_bucket_gcp() {
    local bucket="$1"

    # `gcloud auth login` and `gcloud auth application-default login` hold separate
    # credentials, and the CLI one expires on its own schedule. Terraform reads ADC,
    # so borrow the same token here and the bucket is created by the same identity.
    local token
    if token="$(gcloud auth application-default print-access-token 2>/dev/null)"; then
        export CLOUDSDK_AUTH_ACCESS_TOKEN="$token"
    fi

    if gcloud storage buckets describe "gs://$bucket" >/dev/null 2>&1; then
        return 0
    fi

    [[ -n "$TF_STATE_PROJECT_GCP" ]] ||
        die "Đặt TF_STATE_PROJECT_GCP để biết tạo bucket state trong project nào."

    info "Tạo bucket state gs://$bucket"
    gcloud storage buckets create "gs://$bucket" \
        --project "$TF_STATE_PROJECT_GCP" \
        --location "asia-southeast1" \
        --uniform-bucket-level-access \
        --public-access-prevention
    gcloud storage buckets update "gs://$bucket" --versioning
}

cmd_new() {
    local name="${1:-}" cloud="${2:-}"

    [[ -n "$name" ]]  || die "Thiếu tên. Ví dụ: make tf-new DEPLOY=horizonschool-aws CLOUD=aws"
    [[ -n "$cloud" ]] || die "Thiếu CLOUD=aws hoặc CLOUD=gcp"
    [[ "$cloud" == aws || "$cloud" == gcp ]] || die "CLOUD phải là aws hoặc gcp, không phải '$cloud'."
    [[ "$name" =~ ^[a-z][a-z0-9-]{2,40}$ ]] ||
        die "Tên chỉ gồm chữ thường, số và dấu gạch, bắt đầu bằng chữ."

    local dir="$DEPLOYMENTS/$name"
    [[ ! -e "$dir" ]] || die "$dir đã tồn tại."

    local bucket
    [[ "$cloud" == aws ]] && bucket="$TF_STATE_BUCKET_AWS" || bucket="$TF_STATE_BUCKET_GCP"

    if [[ "${TF_SKIP_BUCKET:-}" == 1 ]]; then
        warn "Bỏ qua việc tạo bucket state; $bucket phải có sẵn."
    elif [[ "$cloud" == aws ]]; then
        ensure_bucket_aws "$bucket"
    else
        ensure_bucket_gcp "$bucket"
    fi

    mkdir -p "$dir"
    cp "terraform/templates/$cloud/main.tf"    "$dir/main.tf"
    cp "terraform/templates/$cloud/outputs.tf" "$dir/outputs.tf"
    cp "terraform/templates/$cloud/terraform.tfvars.example" "$dir/terraform.tfvars"
    # Copied rather than committed twice: the module's variables are the only
    # authored copy, and the deployment gets them fresh at creation time.
    cp "terraform/modules/moodle-$cloud/variables.tf" "$dir/variables.tf"

    sed -i.bak \
        -e "s|TF_STATE_BUCKET|$bucket|g" \
        -e "s|TF_STATE_REGION|$TF_STATE_REGION|g" \
        -e "s|TF_STATE_PROFILE|$TF_STATE_PROFILE|g" \
        -e "s|DEPLOY|$name|g" \
        "$dir/main.tf"
    rm -f "$dir/main.tf.bak"

    # The name must differ per deployment or IAM roles and key pairs collide.
    sed -i.bak "s|^name = .*|name = \"$name\"|" "$dir/terraform.tfvars"
    rm -f "$dir/terraform.tfvars.bak"

    info "Đã tạo $dir"
    echo
    echo "  1. Sửa $dir/terraform.tfvars (credential, region, acme_email)"
    echo "  2. make tf-apply DEPLOY=$name"
    echo
    warn "terraform.tfvars và break-glass.pem trong thư mục này không bao giờ được commit."
}

case "${1:-}" in
    list) cmd_list ;;
    new)  shift; cmd_new "$@" ;;
    *)    die "Dùng: $0 {list|new <tên> <aws|gcp>}" ;;
esac
