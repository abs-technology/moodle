#!/usr/bin/env bash
# =============================================================================
# docker-scout.sh — Build, scan, gate-keep, and push Moodle Docker image.
#
# Mục đích:
#   - Build image với SBOM + Provenance attestations (bắt buộc cho supply-chain).
#   - Quét vulnerabilities và đánh giá 7 policy chuẩn của Docker Scout:
#       1. No high-profile vulnerabilities
#       2. No fixable critical or high vulnerabilities
#       3. No unapproved base images
#       4. Supply chain attestations
#       5. No outdated base images
#       6. No AGPL v3 licenses
#       7. Default non-root user
#   - Chỉ push lên Docker Hub khi tất cả policy pass.
#
# Subcommands:
#   build         Build image (kèm SBOM + provenance).
#   scan          Quét CVE chi tiết (chỉ in, không gate).
#   quickview     In tóm tắt nhanh image hiện tại.
#   policy        Đánh giá toàn bộ policy (gate: exit ≠ 0 khi fail).
#   push          Push image lên registry (yêu cầu policy đã pass).
#   release       build → policy → push  (workflow đầy đủ; mặc định).
#   recommendations  Gợi ý nâng cấp base image / fix CVE.
#
# Cấu hình qua env vars (hoặc CLI flag, xem --help):
#   IMAGE         Tên image, ví dụ abstechnology/moodle-core (bắt buộc).
#   TAG           Tag, ví dụ 4.5.11 (bắt buộc).
#   PLATFORMS     linux/amd64[,linux/arm64]. Mặc định linux/amd64.
#                 Multi-arch: list nhiều platform cách nhau dấu phẩy.
#   GATE_ARCH     Platform dùng cho Scout policy gate trong `release`.
#                 Mặc định linux/amd64 (host build amd64). Đổi sang
#                 linux/arm64 nếu chạy trên Apple Silicon để build nhanh hơn.
#   ORG           Docker Hub org dùng cho policy lookup (mặc định lấy từ IMAGE).
#   DOCKERFILE    Đường dẫn Dockerfile (mặc định ./Dockerfile).
#   CONTEXT       Build context (mặc định ./).
#   BUILD_ARGS    Chuỗi build args, vd "MOODLE_VERSION=4.5.11 PHP_VERSION=8.2".
#   PUSH_ON_FAIL  yes|no — push kể cả khi policy fail (KHÔNG khuyến khích).
#   SKIP_BUILD    yes|no — release dùng image đã có sẵn local.
#   ONLY_SEVERITY critical,high  — severity scan CVE.
#
# Ví dụ:
#   IMAGE=abstechnology/moodle-core TAG=4.5.11 ./scripts/utils/docker-scout.sh release
#   IMAGE=abstechnology/moodle-core TAG=4.5.11 ./scripts/utils/docker-scout.sh policy
#   ./scripts/utils/docker-scout.sh quickview --image abstechnology/moodle-core:4.5.11
# =============================================================================

set -euo pipefail

# ------------------------- Colors / Logging --------------------------------- #
if [[ -t 1 ]] && [[ "${NO_COLOR:-}" != "1" ]]; then
    C_RESET=$'\033[0m'
    C_BOLD=$'\033[1m'
    C_DIM=$'\033[2m'
    C_RED=$'\033[31m'
    C_GREEN=$'\033[32m'
    C_YELLOW=$'\033[33m'
    C_BLUE=$'\033[34m'
    C_CYAN=$'\033[36m'
else
    C_RESET="" C_BOLD="" C_DIM="" C_RED="" C_GREEN="" C_YELLOW="" C_BLUE="" C_CYAN=""
fi

log()    { printf '%s[scout]%s %s\n'      "${C_CYAN}"   "${C_RESET}" "$*"; }
ok()     { printf '%s[ ok ]%s %s\n'       "${C_GREEN}"  "${C_RESET}" "$*"; }
warn()   { printf '%s[warn]%s %s\n'       "${C_YELLOW}" "${C_RESET}" "$*"; }
err()    { printf '%s[fail]%s %s\n' >&2   "${C_RED}"    "${C_RESET}" "$*"; }
hr()     { printf '%s%s%s\n' "${C_DIM}" "------------------------------------------------------------" "${C_RESET}"; }
section(){ printf '\n%s%s>> %s%s\n' "${C_BOLD}" "${C_BLUE}" "$*" "${C_RESET}"; }

# ------------------------- Defaults ----------------------------------------- #
IMAGE="${IMAGE:-}"
TAG="${TAG:-}"
PLATFORMS="${PLATFORMS:-linux/amd64}"
ORG="${ORG:-}"
DOCKERFILE="${DOCKERFILE:-Dockerfile}"
CONTEXT="${CONTEXT:-.}"
BUILD_ARGS="${BUILD_ARGS:-}"
PUSH_ON_FAIL="${PUSH_ON_FAIL:-no}"
SKIP_BUILD="${SKIP_BUILD:-no}"
ONLY_SEVERITY="${ONLY_SEVERITY:-critical,high}"

# Policy slugs Docker Scout dùng để khớp với tiêu chí trong ảnh.
# Trong v1.20+, `docker scout policy <image>` đánh giá tất cả policy đã enable
# cho org. Bạn cũng có thể bật/tắt riêng từng policy tại
# https://hub.docker.com/orgs/<ORG>/policy
DEFAULT_POLICIES=(
    "default-non-root-user"
    "no-agpl-v3-licenses"
    "no-fixable-critical-or-high-vulnerabilities"
    "no-high-profile-vulnerabilities"
    "no-outdated-base-images"
    "no-unapproved-base-images"
    "supply-chain-attestations"
)

# ------------------------- Helpers ------------------------------------------ #
print_help() {
    sed -n '2,/^# ===/p' "$0" | sed 's/^# \{0,1\}//'
}

require() {
    local missing=()
    for c in "$@"; do
        command -v "$c" >/dev/null 2>&1 || missing+=("$c")
    done
    if (( ${#missing[@]} )); then
        err "Thiếu lệnh: ${missing[*]}"
        err "Cài Docker Desktop ≥ 4.24 (bao gồm Docker Scout + Buildx) trước khi tiếp tục."
        exit 127
    fi
}

ensure_docker_scout() {
    require docker
    if ! docker scout version >/dev/null 2>&1; then
        err "'docker scout' chưa cài. Cài qua Docker Desktop hoặc:"
        err "  curl -fsSL https://raw.githubusercontent.com/docker/scout-cli/main/install.sh | sh -s --"
        exit 127
    fi
}

ensure_required_vars() {
    local missing=()
    [[ -z "${IMAGE}" ]] && missing+=("IMAGE")
    [[ -z "${TAG}"   ]] && missing+=("TAG")
    if (( ${#missing[@]} )); then
        err "Thiếu biến: ${missing[*]}"
        err "Ví dụ: IMAGE=abstechnology/moodle-core TAG=4.5.11 $0 $CMD"
        exit 2
    fi
    if [[ -z "${ORG}" ]]; then
        ORG="${IMAGE%%/*}"
    fi
}

full_image() { printf '%s:%s' "${IMAGE}" "${TAG}"; }

ensure_buildx_builder() {
    if ! docker buildx inspect scout-builder >/dev/null 2>&1; then
        log "Tạo buildx builder 'scout-builder' (driver: docker-container, hỗ trợ SBOM/provenance)"
        docker buildx create --name scout-builder --driver docker-container --use >/dev/null
        docker buildx inspect --bootstrap scout-builder >/dev/null
    else
        docker buildx use scout-builder >/dev/null
    fi
}

# ------------------------- Subcommands -------------------------------------- #
cmd_build() {
    ensure_required_vars
    ensure_buildx_builder

    local img; img="$(full_image)"
    section "Build $img ($PLATFORMS) với SBOM + Provenance"

    local -a args=(
        buildx build
        --file "$DOCKERFILE"
        --platform "$PLATFORMS"
        --tag "$img"
        --sbom=true
        --provenance=mode=max
        --label "org.opencontainers.image.source=$(git config --get remote.origin.url 2>/dev/null || echo unknown)"
        --label "org.opencontainers.image.revision=$(git rev-parse HEAD 2>/dev/null || echo unknown)"
        --label "org.opencontainers.image.created=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    )

    # Build args
    if [[ -n "$BUILD_ARGS" ]]; then
        # shellcheck disable=SC2206
        local kvs=( $BUILD_ARGS )
        for kv in "${kvs[@]}"; do
            args+=( --build-arg "$kv" )
        done
    fi

    # Nếu chỉ một platform, --load để image vào local store (cho scout scan).
    # Nếu multi-arch, phải --push hoặc --output để có manifest list — Scout sẽ
    # scan bằng cách pull image, nên user cần đã `docker login` từ trước.
    if [[ "$PLATFORMS" == *","* ]]; then
        warn "Multi-arch build → bắt buộc --push (image sẽ được đẩy lên registry để Scout scan)."
        args+=( --push )
    else
        args+=( --load )
    fi

    args+=( "$CONTEXT" )

    log "Lệnh: docker ${args[*]}"
    docker "${args[@]}"
    ok "Build xong: $img"
}

cmd_quickview() {
    ensure_docker_scout
    ensure_required_vars
    local img; img="$(full_image)"
    section "Quickview $img"
    docker scout quickview "$img"
}

cmd_scan() {
    ensure_docker_scout
    ensure_required_vars
    local img; img="$(full_image)"
    section "CVE scan $img (severity: $ONLY_SEVERITY)"
    docker scout cves "$img" --only-severity "$ONLY_SEVERITY" --details || {
        warn "Có CVE ở mức $ONLY_SEVERITY — xem chi tiết phía trên."
        return 1
    }
    ok "Không phát hiện CVE ở mức $ONLY_SEVERITY"
}

cmd_recommendations() {
    ensure_docker_scout
    ensure_required_vars
    section "Recommendations $(full_image)"
    docker scout recommendations "$(full_image)"
}

cmd_policy() {
    ensure_docker_scout
    ensure_required_vars
    local img; img="$(full_image)"

    section "Policy evaluation $img  (org: $ORG)"
    log "7 policy chuẩn được kiểm tra:"
    for p in "${DEFAULT_POLICIES[@]}"; do
        printf '  • %s\n' "$p"
    done
    hr

    # `docker scout policy` đánh giá tất cả policy đã enable cho org.
    # --exit-on policy → exit code ≠ 0 nếu có policy fail (gate-keeper).
    # --org giúp Scout dùng đúng policy config trên Hub.
    local rc=0
    if ! docker scout policy "$img" --org "$ORG" --exit-on policy; then
        rc=$?
    fi

    hr
    if (( rc == 0 )); then
        ok "Tất cả policy ĐẠT — image sẵn sàng push."
    else
        err "Policy FAIL (exit=$rc). Image $img chưa đạt chuẩn."
        err "Chạy '$0 recommendations' để xem gợi ý sửa."
    fi
    return $rc
}

cmd_push() {
    ensure_required_vars
    local img; img="$(full_image)"
    section "Push $img → Docker Hub"

    # Kiểm tra đã login chưa.
    local registry="docker.io"
    if [[ "$IMAGE" == */*/* ]]; then
        registry="${IMAGE%%/*}"
    fi
    if ! docker info 2>/dev/null | grep -q "Username:"; then
        warn "Chưa thấy Docker Hub login. Chạy: docker login $registry"
    fi

    docker push "$img"
    ok "Đã push: $img"
}

cmd_release() {
    ensure_docker_scout
    ensure_required_vars
    local img; img="$(full_image)"

    section "RELEASE workflow → $img"
    log "Phases: 1) build gate-arch local + policy gate  2) build & push (multi-arch nếu cấu hình)"
    hr

    # ----- Phase 1: build single-arch local để Scout gate ------------------ #
    local gate_arch="${GATE_ARCH:-linux/amd64}"
    local original_platforms="$PLATFORMS"

    if [[ "$SKIP_BUILD" != "yes" ]]; then
        log "Phase 1 — build $gate_arch local cho policy gate"
        PLATFORMS="$gate_arch" cmd_build
    else
        warn "SKIP_BUILD=yes → bỏ qua build, dùng image local hiện có."
    fi

    cmd_quickview || true

    if ! cmd_policy; then
        local rc=$?
        if [[ "$PUSH_ON_FAIL" == "yes" ]]; then
            warn "Policy fail nhưng PUSH_ON_FAIL=yes → vẫn push (arch: $gate_arch)."
            cmd_push
            exit "$rc"
        fi
        err "RELEASE ABORT: $img không pass policy. Không push."
        err "Set PUSH_ON_FAIL=yes để override (KHÔNG khuyến khích)."
        exit "$rc"
    fi

    # ----- Phase 2: push thật (single hoặc multi-arch) --------------------- #
    if [[ "$original_platforms" == *","* ]]; then
        section "Phase 2 — multi-arch build & push ($original_platforms)"
        log "Đã pass policy trên $gate_arch — rebuild đủ arch và push thẳng lên registry."
        PLATFORMS="$original_platforms" SKIP_BUILD=no cmd_build
        ok "RELEASE OK: $img (multi-arch: $original_platforms) build + push xong, policy pass."
    else
        section "Phase 2 — push single-arch ($gate_arch)"
        cmd_push
        ok "RELEASE OK: $img đã được scan đạt chuẩn và push thành công."
    fi
}

# ------------------------- CLI parsing -------------------------------------- #
CMD="${1:-help}"
shift || true

# Cho phép --image / --tag / --platforms / --org override env vars.
while (( "$#" )); do
    case "$1" in
        --image)     IMAGE="$2"; shift 2 ;;
        --tag)       TAG="$2"; shift 2 ;;
        --platforms) PLATFORMS="$2"; shift 2 ;;
        --org)       ORG="$2"; shift 2 ;;
        --build-args)BUILD_ARGS="$2"; shift 2 ;;
        --skip-build)SKIP_BUILD=yes; shift ;;
        --push-on-fail) PUSH_ON_FAIL=yes; shift ;;
        --severity)  ONLY_SEVERITY="$2"; shift 2 ;;
        --help|-h)   print_help; exit 0 ;;
        *)           err "Tham số không hợp lệ: $1"; exit 2 ;;
    esac
done

case "$CMD" in
    build)            cmd_build ;;
    scan|cves)        cmd_scan ;;
    quickview|qv)     cmd_quickview ;;
    policy)           cmd_policy ;;
    push)             cmd_push ;;
    recommendations|recs) cmd_recommendations ;;
    release|all)      cmd_release ;;
    help|--help|-h|"") print_help ;;
    *) err "Subcommand không hợp lệ: $CMD"; print_help; exit 2 ;;
esac
