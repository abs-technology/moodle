#!/usr/bin/env bash
# Scaffold and list Terraform deployments. One directory per customer site, each
# with its own state object, so no apply can reach another customer's stack.
#
#   scripts/tf-deployments.sh new horizonschool-aws aws
#   scripts/tf-deployments.sh list
set -Eeuo pipefail

cd "$(dirname "$(readlink -f "$0")")/.."

# AWS CLI v2 đẩy output qua less khi stdout là terminal, và script chạy dưới `make`
# vẫn thấy terminal. Một lệnh chỉ để kiểm tra sẽ mở pager rồi đứng chờ bấm phím,
# trông đúng như treo. Tắt hẳn pager cho mọi lệnh aws trong script.
export AWS_PAGER=""

GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'; RED=$'\033[0;31m'; NC=$'\033[0m'
info() { printf '%s==>%s %s\n' "$GREEN" "$NC" "$*"; }
warn() { printf '%s[!]%s %s\n' "$YELLOW" "$NC" "$*" >&2; }
die()  { printf '%s[x]%s %s\n' "$RED" "$NC" "$*" >&2; exit 1; }

# Tên bucket state được suy ra từ account (AWS) hoặc project (GCP) của chính
# deployment, nên state luôn nằm cùng chỗ với hạ tầng. Đặt TF_STATE_BUCKET nếu bạn
# muốn tên khác, nhưng hãy giữ nguyên tắc một bucket cho một account.

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

        # Remote state: terraform output needs the same credentials as apply.
        # Without them AWS falls through to the machine profile (wrong account)
        # and this line becomes "-". GCP often works anyway via ADC.
        if [[ -f "$dir/terraform.tfvars" ]]; then
            eval "$(cmd_env "$name")"
        fi

        ip="$(terraform -chdir="$dir" output -raw public_ip 2>/dev/null || echo -)"
        [[ -n "$ip" && "$ip" != "null" ]] || ip=-

        # tfvars first: change-domain.sh moves the live domain on the VM, and the
        # only record of that on this side is whoever updated moodle_domain.
        domain="$(sed -n 's/^ *moodle_domain *= *"\(.*\)"/\1/p' "$dir/terraform.tfvars" 2>/dev/null | head -1)"
        [[ -n "$domain" ]] || domain="$(terraform -chdir="$dir" output -raw site_url 2>/dev/null | sed 's|^https://||' || true)"
        [[ -n "$domain" ]] || domain=-

        printf '%-26s %-6s %-16s %s\n' "$name" "$cloud" "$ip" "$domain"
    done
}

ensure_bucket_aws() {
    local bucket="$1" region="$2"
    # head-bucket trả JSON ở CLI mới, và ở đây chỉ cần exit code.
    if aws s3api head-bucket --bucket "$bucket" >/dev/null 2>&1; then
        return 0
    fi

    info "Tạo bucket state s3://$bucket ($region)"
    aws s3api create-bucket --bucket "$bucket" --region "$region" \
        --create-bucket-configuration "LocationConstraint=$region" >/dev/null

    # State holds the generated Moodle and MariaDB passwords in plaintext.
    aws s3api put-public-access-block --bucket "$bucket" \
        --public-access-block-configuration \
        'BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true'
    aws s3api put-bucket-encryption --bucket "$bucket" \
        --server-side-encryption-configuration \
        '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
    # Versioning is what turns a corrupted or truncated state into a rollback.
    aws s3api put-bucket-versioning --bucket "$bucket" \
        --versioning-configuration Status=Enabled
}

ensure_bucket_gcp() {
    local bucket="$1" project="$2" region="$3"

    # `gcloud auth login` and `gcloud auth application-default login` hold separate
    # credentials, and the CLI one expires on its own schedule. Terraform reads ADC,
    # so borrow the same token here and the bucket is created by the same identity.
    local token
    if [[ -z "${GOOGLE_APPLICATION_CREDENTIALS:-}" ]] &&
       token="$(gcloud auth application-default print-access-token 2>/dev/null)"; then
        export CLOUDSDK_AUTH_ACCESS_TOKEN="$token"
    fi

    if gcloud storage buckets describe "gs://$bucket" >/dev/null 2>&1; then
        return 0
    fi

    info "Tạo bucket state gs://$bucket ($project)"
    gcloud storage buckets create "gs://$bucket" \
        --project "$project" \
        --location "$region" \
        --uniform-bucket-level-access \
        --public-access-prevention
    gcloud storage buckets update "gs://$bucket" --versioning
}

# Đọc một giá trị chuỗi từ terraform.tfvars của deployment.
tfvar() { sed -n "s/^ *$2 *= *\"\(.*\)\"/\1/p" "$1/terraform.tfvars" 2>/dev/null | head -1; }

cloud_of() {
    [[ -f "$1/main.tf" ]] || die "$1 chưa có main.tf."
    if grep -q 'provider "aws"' "$1/main.tf"; then echo aws
    elif grep -q 'provider "google"' "$1/main.tf"; then echo gcp
    else die "Không nhận ra cloud của $1."; fi
}

# In ra các lệnh export để `eval`. Backend của Terraform không nhận biến, nên cách
# duy nhất để nó dùng đúng credential của deployment là qua biến môi trường — và đó
# cũng là cách bảo đảm state với hạ tầng không bao giờ lạc sang hai account khác nhau.
cmd_env() {
    local name="${1:-}" dir
    [[ -n "$name" ]] || die "Thiếu tên deployment."
    dir="$DEPLOYMENTS/$name"
    [[ -f "$dir/terraform.tfvars" ]] || die "Thiếu $dir/terraform.tfvars"

    case "$(cloud_of "$dir")" in
    aws)
        local ak sk pf rg
        ak="$(tfvar "$dir" access_key)"; sk="$(tfvar "$dir" secret_key)"
        pf="$(tfvar "$dir" profile)";    rg="$(tfvar "$dir" region)"
        echo "unset AWS_PROFILE AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY"
        [[ -n "$rg" ]] && echo "export AWS_REGION=$(printf '%q' "$rg")"
        if [[ -n "$ak" && -n "$sk" ]]; then
            echo "export AWS_ACCESS_KEY_ID=$(printf '%q' "$ak")"
            echo "export AWS_SECRET_ACCESS_KEY=$(printf '%q' "$sk")"
        elif [[ -n "$pf" ]]; then
            echo "export AWS_PROFILE=$(printf '%q' "$pf")"
        fi
        echo "export AWS_PAGER="
        ;;
    gcp)
        local cred
        cred="$(tfvar "$dir" credentials)"
        [[ -n "$cred" ]] && echo "export GOOGLE_APPLICATION_CREDENTIALS=$(printf '%q' "$cred")"
        ;;
    esac
}

# Sinh backend.tf trong đúng account/project của deployment. Idempotent, và tuyệt
# đối không ghi đè backend đã có: dời state là việc phải làm có ý thức, còn âm thầm
# trỏ sang bucket khác thì Terraform sẽ coi như chưa có gì và định tạo lại tất cả.
cmd_backend() {
    local name="${1:-}" dir bucket
    [[ -n "$name" ]] || die "Thiếu tên deployment."
    dir="$DEPLOYMENTS/$name"
    [[ -f "$dir/terraform.tfvars" ]] || die "Thiếu $dir/terraform.tfvars"
    if [[ -f "$dir/backend.tf" ]] || grep -q 'backend "' "$dir/main.tf"; then
        return 0
    fi

    eval "$(cmd_env "$name")"

    case "$(cloud_of "$dir")" in
    aws)
        local acct region
        region="$(tfvar "$dir" region)"
        [[ -n "$region" ]] || die "Thiếu region trong $dir/terraform.tfvars"
        if [[ -n "${TF_STATE_BUCKET:-}" ]]; then
            bucket="$TF_STATE_BUCKET"; acct="do TF_STATE_BUCKET chỉ định"
        else
            # Tên bucket lấy theo account, nên không thể trỏ nhầm sang account khác.
            acct="$(aws sts get-caller-identity --query Account --output text)" ||
                die "Không xác thực được với AWS bằng credential trong $dir/terraform.tfvars"
            bucket="absi-moodle-tfstate-$acct"
        fi
        [[ "${TF_SKIP_BUCKET:-}" == 1 ]] || ensure_bucket_aws "$bucket" "$region"
        cat >"$dir/backend.tf" <<EOF
# Sinh tự động bởi scripts/tf-deployments.sh. Bucket nằm cùng account với hạ tầng
# ($acct), vì cả hai đều dùng credential trong terraform.tfvars của deployment này.
terraform {
  backend "s3" {
    bucket       = "$bucket"
    key          = "deployments/$name.tfstate"
    region       = "$region"
    encrypt      = true
    use_lockfile = true
  }
}
EOF
        ;;
    gcp)
        local project region
        project="$(tfvar "$dir" project_id)"
        region="$(tfvar "$dir" region)"
        [[ -n "$project" ]] || die "Thiếu project_id trong $dir/terraform.tfvars"
        bucket="${TF_STATE_BUCKET:-absi-moodle-tfstate-$project}"
        [[ "${TF_SKIP_BUCKET:-}" == 1 ]] ||
            ensure_bucket_gcp "$bucket" "$project" "${region:-asia-southeast1}"
        cat >"$dir/backend.tf" <<EOF
# Sinh tự động bởi scripts/tf-deployments.sh, trong project $project — cùng project
# với hạ tầng, vì project_id lấy từ terraform.tfvars của chính deployment này.
terraform {
  backend "gcs" {
    bucket = "$bucket"
    prefix = "deployments/$name"
  }
}
EOF
        ;;
    esac
    info "Đã sinh $dir/backend.tf"
}

cmd_new() {
    local name="${1:-}" cloud="${2:-}"

    [[ -n "$name" ]] || die "Thiếu tên. Ví dụ: make new horizonschool-aws"

    # Hậu tố tên đã nói cloud nào, nên không bắt gõ thêm lần nữa; CLOUD= vẫn đè được
    # nếu bạn muốn tên không theo quy ước.
    if [[ -z "$cloud" ]]; then
        case "$name" in
            *-aws) cloud=aws ;;
            *-gcp) cloud=gcp ;;
            *) die "Tên '$name' không kết thúc bằng -aws hay -gcp; thêm CLOUD=aws hoặc CLOUD=gcp." ;;
        esac
    fi
    [[ "$cloud" == aws || "$cloud" == gcp ]] || die "CLOUD phải là aws hoặc gcp, không phải '$cloud'."
    [[ "$name" =~ ^[a-z][a-z0-9-]{2,40}$ ]] ||
        die "Tên chỉ gồm chữ thường, số và dấu gạch, bắt đầu bằng chữ."

    local dir="$DEPLOYMENTS/$name"
    [[ ! -e "$dir" ]] || die "$dir đã tồn tại."

    # Bucket state chưa tạo được ở bước này: nó phải nằm trong account mà credential
    # trỏ tới, mà credential thì chính bạn sắp điền vào tfvars. `make apply` lo phần đó.
    mkdir -p "$dir"
    cp "terraform/templates/$cloud/main.tf"    "$dir/main.tf"
    cp "terraform/templates/$cloud/outputs.tf" "$dir/outputs.tf"
    cp "terraform/templates/$cloud/terraform.tfvars.example" "$dir/terraform.tfvars"
    # Copied rather than committed twice: the module's variables are the only
    # authored copy, and the deployment gets them fresh at creation time.
    cp "terraform/modules/moodle-$cloud/variables.tf" "$dir/variables.tf"

    sed -i.bak -e "s|DEPLOY|$name|g" "$dir/main.tf"
    rm -f "$dir/main.tf.bak"

    # The name must differ per deployment or IAM roles and key pairs collide.
    sed -i.bak "s|^name = .*|name = \"$name\"|" "$dir/terraform.tfvars"
    rm -f "$dir/terraform.tfvars.bak"

    info "Đã tạo $dir"
    echo
    echo "  1. Sửa $dir/terraform.tfvars (credential, region, acme_email)"
    echo "  2. make apply $name"
    echo
    echo "  Bucket state sẽ được tạo ở bước 2, trong đúng account mà credential trỏ tới."
    echo
    warn "terraform.tfvars và break-glass.pem trong thư mục này không bao giờ được commit."
}

case "${1:-}" in
    list)    cmd_list ;;
    new)     shift; cmd_new "$@" ;;
    backend) shift; cmd_backend "$@" ;;
    env)     shift; cmd_env "$@" ;;
    *)       die "Dùng: $0 {list|new <tên> <aws|gcp>|backend <tên>|env <tên>}" ;;
esac
