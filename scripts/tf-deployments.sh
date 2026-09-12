#!/usr/bin/env bash
# Scaffold and list Terraform deployments. One directory per customer site, each
# with its own state object, so no apply can reach another customer's stack.
#
#   make create aws-traefik school-b
#   make plan|apply|destroy|ssh|output aws-traefik school-b
#   make tf-list
set -Eeuo pipefail

TF="${TF:-terraform}"

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

usage_cli() {
    cat >&2 <<'EOF'
Cú pháp (AWS; GCP đổi aws → gcp):

  make create  aws-traefik|aws-ip|aws-alb <name>
  make plan    aws-traefik|aws-ip|aws-alb <name>
  make apply   aws-traefik|aws-ip|aws-alb <name>
  make destroy aws-traefik|aws-ip|aws-alb <name>
  make ssh     aws-traefik|aws-ip|aws-alb <name>
  make output  aws-traefik|aws-ip|aws-alb <name>
  make tf-list

Ví dụ: make create aws-traefik school-b
       make apply  gcp-alb     moodle-alb
aws-alb chưa có — dùng gcp-alb.
EOF
}

cmd_list() {
    [[ -d "$DEPLOYMENTS" ]] || { echo "Chưa có deployment nào."; return 0; }

    printf '%-28s %-14s %-16s %s\n' DEPLOYMENT TRACK IP DOMAIN
    local dir name cloud kind track ip domain
    for dir in "$DEPLOYMENTS"/*/; do
        [[ -d "$dir" ]] || continue
        name="$(basename "$dir")"
        cloud="$(cloud_guess "$dir")"
        kind="$(kind_of "$dir")"
        track="${cloud}-${kind}"

        # Remote state: terraform output needs the same credentials as apply.
        # Without them AWS falls through to the machine profile (wrong account)
        # and this line becomes "-". GCP often works anyway via ADC.
        if [[ -f "$dir/terraform.tfvars" ]]; then
            eval "$(cmd_env "$name")"
        fi

        ip="$($TF -chdir="$dir" output -raw public_ip 2>/dev/null || echo -)"
        [[ -n "$ip" && "$ip" != "null" ]] || ip=-

        # tfvars first: change-domain.sh moves the live domain on the VM, and the
        # only record of that on this side is whoever updated moodle_domain.
        domain="$(sed -n 's/^ *moodle_domain *= *"\(.*\)"/\1/p' "$dir/terraform.tfvars" 2>/dev/null | head -1)"
        [[ -n "$domain" ]] || domain="$($TF -chdir="$dir" output -raw site_url 2>/dev/null | sed -E 's|^https?://||' || true)"
        [[ -n "$domain" ]] || domain=-

        printf '%-28s %-14s %-16s %s\n' "$name" "$track" "$ip" "$domain"
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

is_alb() { [[ -f "$1/frontend.alb" ]]; }
is_ip()  { [[ -f "$1/frontend.ip" ]]; }
is_traefik() {
    [[ -f "$1/frontend.traefik" ]] && return 0
    # Sites created before frontend.traefik: no other marker means Traefik.
    ! is_alb "$1" && ! is_ip "$1"
}

kind_of() {
    if is_alb "$1"; then echo alb
    elif is_ip "$1"; then echo ip
    else echo traefik
    fi
}

cloud_guess() {
    grep -q 'provider "aws"' "$1/main.tf" 2>/dev/null && { echo aws; return 0; }
    grep -q 'provider "google"' "$1/main.tf" 2>/dev/null && { echo gcp; return 0; }
    echo unknown
}

parse_track() {
    local track="${1:-}"
    case "$track" in
        aws-traefik|aws-ip|aws-alb|gcp-traefik|gcp-ip|gcp-alb)
            TRACK_CLOUD="${track%-*}"
            TRACK_KIND="${track#*-}"
            ;;
        *)
            [[ -n "$track" ]] || die "Thiếu track (aws-traefik, aws-ip, gcp-alb, …)."
            die "Track '$track' không hợp lệ."
            ;;
    esac
    if [[ "$TRACK_CLOUD" == aws && "$TRACK_KIND" == alb ]]; then
        die "aws-alb chưa có. Dùng gcp-alb, hoặc đợi giai đoạn AWS."
    fi
}

# Thư mục trên đĩa vẫn là <name>-aws / <name>-gcp để AWS và GCP không đụng nhau.
# Lệnh make không bắt gõ lại hậu tố: create aws-traefik school-b → school-b-aws.
dir_name_for() {
    local app="$1" cloud="$2"
    case "$app" in
        *-aws)
            [[ "$cloud" == aws ]] || die "Tên '$app' là AWS nhưng track là ${cloud}-*."
            echo "$app"
            ;;
        *-gcp)
            [[ "$cloud" == gcp ]] || die "Tên '$app' là GCP nhưng track là ${cloud}-*."
            echo "$app"
            ;;
        *)
            echo "${app}-${cloud}"
            ;;
    esac
}

need_track_name() {
    local track="${1:-}" app="${2:-}"
    [[ -n "$track" && -n "$app" ]] || { usage_cli; exit 1; }
    [[ "$app" != *" "* ]] || die "Mỗi lệnh một tên app, không phải: $app"
    parse_track "$track"
}

# Tìm thư mục thật: school-b hoặc school-b-aws đều được nếu cloud + type khớp track.
resolve_dir() {
    local app="$1" cand dir found=""
    local -a cands=("$app")
    case "$app" in
        *-aws|*-gcp) ;;
        *) cands+=("${app}-${TRACK_CLOUD}") ;;
    esac
    for cand in "${cands[@]}"; do
        dir="$DEPLOYMENTS/$cand"
        [[ -d "$dir" && -f "$dir/main.tf" ]] || continue
        [[ "$(cloud_guess "$dir")" == "$TRACK_CLOUD" ]] || continue
        [[ "$(kind_of "$dir")" == "$TRACK_KIND" ]] || continue
        found="$cand"
        break
    done
    [[ -n "$found" ]] ||
        die "Không có deployment '$app' loại ${TRACK_CLOUD}-${TRACK_KIND}. Xem: make tf-list"
    echo "$found"
}

cmd_new() {
    local name="$1" cloud="$2" kind="$3" track="$4" shown="${5:-$1}"
    [[ "$name" =~ ^[a-z][a-z0-9-]{2,30}$ ]] ||
        die "Tên thư mục phải là chữ thường, số và dấu gạch, 3–31 ký tự (khớp var.name)."

    local dir="$DEPLOYMENTS/$name" tmpl="terraform/templates/${cloud}-${kind}"
    [[ ! -e "$dir" ]] || die "$dir đã tồn tại."
    [[ -d "$tmpl" ]] || die "Thiếu template $tmpl."

    mkdir -p "$dir"
    cp "$tmpl/main.tf"    "$dir/main.tf"
    cp "$tmpl/outputs.tf" "$dir/outputs.tf"
    cp "$tmpl/terraform.tfvars.example" "$dir/terraform.tfvars"
    cp "terraform/modules/moodle-$cloud/variables.tf" "$dir/variables.tf"
    case "$kind" in
        alb)     cp "$tmpl/frontend.alb" "$dir/frontend.alb" ;;
        ip)      cp "$tmpl/frontend.ip" "$dir/frontend.ip" ;;
        traefik) cp "$tmpl/frontend.traefik" "$dir/frontend.traefik" ;;
        *)       die "kind phải là traefik, ip hoặc alb." ;;
    esac

    sed -i.bak -e "s|DEPLOY|$name|g" "$dir/main.tf"
    rm -f "$dir/main.tf.bak"
    sed -i.bak "s|^name = .*|name = \"$name\"|" "$dir/terraform.tfvars"
    rm -f "$dir/terraform.tfvars.bak"

    info "Đã tạo $dir"
    echo
    echo "  1. Sửa $dir/terraform.tfvars (credential, region, acme_email)"
    echo "  2. make apply $track $shown"
    echo
    echo "  Bucket state sẽ được tạo ở bước 2, trong đúng account mà credential trỏ tới."
    echo
    warn "terraform.tfvars và break-glass.pem trong thư mục này không bao giờ được commit."
}

cmd_create() {
    local track="${1:-}" app="${2:-}" dir_name
    need_track_name "$track" "$app"
    dir_name="$(dir_name_for "$app" "$TRACK_CLOUD")"
    cmd_new "$dir_name" "$TRACK_CLOUD" "$TRACK_KIND" "$track" "$app"
}

with_tf() {
    local name="$1"; shift
    local dir="$DEPLOYMENTS/$name"
    eval "$(cmd_env "$name")"
    "$@"
}

cmd_plan() {
    local track="${1:-}" app="${2:-}" name
    need_track_name "$track" "$app"
    name="$(resolve_dir "$app")"
    cmd_backend "$name"
    with_tf "$name" $TF -chdir="$DEPLOYMENTS/$name" init -input=false
    with_tf "$name" $TF -chdir="$DEPLOYMENTS/$name" plan
}

cmd_apply() {
    local track="${1:-}" app="${2:-}" name
    need_track_name "$track" "$app"
    name="$(resolve_dir "$app")"
    cmd_backend "$name"
    with_tf "$name" $TF -chdir="$DEPLOYMENTS/$name" init -input=false -upgrade
    with_tf "$name" $TF -chdir="$DEPLOYMENTS/$name" apply
}

cmd_destroy() {
    local track="${1:-}" app="${2:-}" name
    need_track_name "$track" "$app"
    name="$(resolve_dir "$app")"
    with_tf "$name" $TF -chdir="$DEPLOYMENTS/$name" destroy
}

cmd_output() {
    local track="${1:-}" app="${2:-}" name
    need_track_name "$track" "$app"
    name="$(resolve_dir "$app")"
    with_tf "$name" $TF -chdir="$DEPLOYMENTS/$name" output -json |
        python3 -c 'import json,sys; [print("%-24s %s" % (k, v["value"])) for k, v in json.load(sys.stdin).items()]'
}

cmd_ssh() {
    local track="${1:-}" app="${2:-}" name dir
    need_track_name "$track" "$app"
    name="$(resolve_dir "$app")"
    dir="$DEPLOYMENTS/$name"
    eval "$(cmd_env "$name")"
    (
        cd "$dir"
        if [[ "$TRACK_KIND" == alb ]]; then
            eval "$($TF output -raw iap_ssh_command)"
        elif [[ -f break-glass.pem ]]; then
            ssh -i break-glass.pem "admin@$($TF output -raw public_ip)"
        else
            eval "$($TF output -raw ssh_command)"
        fi
    )
}

cmd_legacy() {
    usage_cli
    die "Lệnh cũ '$1' đã đổi. Dùng make create|plan|apply|destroy <track> <name>."
}

case "${1:-}" in
    list|tf-list)    cmd_list ;;
    create)          shift; cmd_create "$@" ;;
    plan)            shift; cmd_plan "$@" ;;
    apply)           shift; cmd_apply "$@" ;;
    destroy)         shift; cmd_destroy "$@" ;;
    output)          shift; cmd_output "$@" ;;
    ssh)             shift; cmd_ssh "$@" ;;
    backend)         shift; cmd_backend "$@" ;;
    env)             shift; cmd_env "$@" ;;
    legacy)          shift; cmd_legacy "$@" ;;
    -h|--help|help)  usage_cli; exit 0 ;;
    *)               usage_cli; exit 1 ;;
esac
