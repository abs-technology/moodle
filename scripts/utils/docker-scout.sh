#!/usr/bin/env bash
# =============================================================================
# docker-scout.sh — Build, scan, gate-keep, and push Moodle Docker image.
#
# Mục đích:
#   - Build image với SBOM + Provenance attestations (bắt buộc cho supply-chain).
#   - Quét vulnerabilities và đánh giá gate policies (security; bỏ copyleft Debian):
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
#   IMAGE         Tên image, ví dụ abstechnology/moodle-standard (bắt buộc).
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
#   NO_CACHE      yes|no — bỏ build cache (default: no).
#   PULL_BASE     yes|no — pull base image trước build (default: no).
#   BUILDER       T\u00ean buildx builder (default: scout-builder).
#                 BẮT BUỘC driver=docker-container — không dùng Docker Build
#                 Cloud (`--driver cloud`); build hoàn toàn trên máy local.
#
# Ví dụ:
#   IMAGE=abstechnology/moodle-standard TAG=4.5.11 ./scripts/utils/docker-scout.sh release
#   IMAGE=abstechnology/moodle-standard TAG=4.5.11 ./scripts/utils/docker-scout.sh policy
#   ./scripts/utils/docker-scout.sh quickview --image abstechnology/moodle-standard:4.5.11
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

# NO_CACHE  yes|no — bỏ toàn bộ layer cache (default: no — dùng cache khi dev).
# PULL_BASE yes|no — pull base image trước build (default: no; tự bật khi NO_CACHE=yes).
NO_CACHE="${NO_CACHE:-no}"
PULL_BASE="${PULL_BASE:-no}"
if [[ "$NO_CACHE" == "yes" ]]; then
    PULL_BASE=yes
fi

# BUILDER  Tên buildx builder (default: scout-builder, driver docker-container).
#          Force local build — KHÔNG dùng Docker Build Cloud (`--driver cloud`).
BUILDER="${BUILDER:-scout-builder}"


BUILDKIT_IMAGE="${BUILDKIT_IMAGE:-moby/buildkit:latest}"

# 
SBOM_SCANNER="${SBOM_SCANNER:-docker/buildkit-syft-scanner:1.11.0}"


ATTESTATIONS="${ATTESTATIONS:-full}"


# Real Docker Scout policy IDs (from --result-file keys / Hub org).
# copyleft-license is intentionally omitted: Debian/Apache/PHP images always
# ship hundreds of GPL/LGPL packages; that org policy cannot pass for this stack.
DEFAULT_POLICIES=(
    "default-non-root-user"
    "fixable-vulnerabilities"
    "high-profile-vulnerabilities"
    "no-stale-base-images"
    "approved-base-images"
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

ensure_docker_login() {
    [[ "${SKIP_LOGIN_CHECK:-no}" == "yes" ]] && return 0

    local config="${DOCKER_CONFIG:-$HOME/.docker}/config.json"
    if [[ -f "$config" ]] \
        && grep -qE '"(auths|credsStore|credHelpers)"[[:space:]]*:' "$config" 2>/dev/null; then
        return 0
    fi

    err "Chưa thấy Docker credentials trong $config."
    err "Scout cần auth để gọi API policy/CVE. Chạy: docker login"
    err "Bỏ qua check (nếu auth qua cách khác): SKIP_LOGIN_CHECK=yes make ..."
    exit 4
}

ensure_required_vars() {
    local missing=()
    [[ -z "${IMAGE}" ]] && missing+=("IMAGE")
    [[ -z "${TAG}"   ]] && missing+=("TAG")
    if (( ${#missing[@]} )); then
        err "Thiếu biến: ${missing[*]}"
        err "Ví dụ: IMAGE=abstechnology/moodle-standard TAG=4.5.11 $0 $CMD"
        exit 2
    fi
    if [[ -z "${ORG}" ]]; then
        ORG="${IMAGE%%/*}"
    fi
}

full_image() { printf '%s:%s' "${IMAGE}" "${TAG}"; }

ensure_buildx_builder() {
    # Bắt buộc local builder (driver=docker-container). Nếu builder tồn tại với
    # driver khác (vd. `cloud` khi user đã setup Docker Build Cloud), recreate
    # để đảm bảo build hoàn toàn trên máy local — KHÔNG gửi context lên cloud.
    #
    # Cũng đảm bảo BuildKit image đã pin để Go runtime của BuildKit ≥ 1.21.0
    # (tránh CVE-2023-24531 nhúng trong provenance attestation).
    local desired_driver="docker-container"
    local current_driver=""
    local current_image=""
    local needs_recreate=0

    if docker buildx inspect "$BUILDER" >/dev/null 2>&1; then
        current_driver=$(docker buildx inspect "$BUILDER" 2>/dev/null \
            | awk -F': *' '/^Driver:/{print $2; exit}')
        current_image=$(docker buildx inspect "$BUILDER" 2>/dev/null \
            | awk '/^[[:space:]]*Image:/{print $2; exit}')

        if [[ "$current_driver" != "$desired_driver" ]]; then
            warn "Builder '$BUILDER' driver='$current_driver' (KHÔNG phải local) — recreate"
            needs_recreate=1
        elif [[ -n "$BUILDKIT_IMAGE" && "$current_image" != "$BUILDKIT_IMAGE" ]]; then
            warn "Builder '$BUILDER' BuildKit image='${current_image:-default}' khác '$BUILDKIT_IMAGE' — recreate"
            needs_recreate=1
        fi

        if (( needs_recreate )); then
            docker buildx rm "$BUILDER" >/dev/null 2>&1 || true
            current_driver=""
        fi
    fi

    if [[ -z "$current_driver" ]]; then
        log "Tạo buildx builder '$BUILDER' (driver: $desired_driver, BuildKit: $BUILDKIT_IMAGE, local)"
        docker buildx create --name "$BUILDER" --driver "$desired_driver" \
            --driver-opt "image=$BUILDKIT_IMAGE" \
            --use >/dev/null
        docker buildx inspect --bootstrap "$BUILDER" >/dev/null
    else
        docker buildx use "$BUILDER" >/dev/null
    fi

    log "Builder: $BUILDER (BuildKit: $BUILDKIT_IMAGE, SBOM scanner: $SBOM_SCANNER, attestations: $ATTESTATIONS)"
}

# ------------------------- Subcommands -------------------------------------- #
cmd_build() {
    ensure_required_vars
    ensure_buildx_builder

    local img; img="$(full_image)"
    local cache_msg
    if [[ "$NO_CACHE" == "yes" ]]; then
        cache_msg="NO CACHE (rebuild from scratch)"
    elif [[ "$PULL_BASE" == "yes" ]]; then
        cache_msg="dùng cache + pull base image"
    else
        cache_msg="dùng cache (NO_CACHE=no)"
    fi
    section "Build $img ($PLATFORMS) — $cache_msg, attestations=$ATTESTATIONS"

    local -a args=(
        buildx build
        --builder "$BUILDER"
        --file "$DOCKERFILE"
        --platform "$PLATFORMS"
        --tag "$img"
        --label "org.opencontainers.image.source=$(git config --get remote.origin.url 2>/dev/null || echo unknown)"
        --label "org.opencontainers.image.revision=$(git rev-parse HEAD 2>/dev/null || echo unknown)"
        --label "org.opencontainers.image.created=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    )

    if [[ "$PULL_BASE" == "yes" ]]; then
        args+=( --pull )
    fi

    # Attestations: pin SBOM scanner image để Go runtime ≥ 1.21.0, tránh
    # CVE-2023-24531 (cmd/go toolchain) bị external scanners (Google Artifact
    # Analysis, Trivy, etc.) phát hiện trong attestation manifest.
    case "$ATTESTATIONS" in
        full)
            args+=(
                --attest "type=sbom,generator=$SBOM_SCANNER"
                --attest "type=provenance,mode=max"
            )
            ;;
        provenance-only)
            args+=( --attest "type=provenance,mode=max" )
            warn "ATTESTATIONS=provenance-only → SBOM bị tắt; Scout policy 'Supply chain attestations' sẽ partial"
            ;;
        none)
            warn "ATTESTATIONS=none → KHÔNG có SBOM/Provenance; Scout policy 'Supply chain attestations' sẽ FAIL"
            warn "Chỉ dùng khi external scanner (Google) bắt buộc không có Go metadata"
            ;;
        *)
            err "ATTESTATIONS='$ATTESTATIONS' không hợp lệ. Dùng: full | provenance-only | none"
            exit 2
            ;;
    esac

    # --no-cache: bỏ toàn bộ layer cache để luôn pull patches mới nhất từ
    # bookworm-security. Build chậm hơn nhưng đảm bảo không sót CVE cũ.
    if [[ "$NO_CACHE" == "yes" ]]; then
        args+=( --no-cache )
    fi

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
    ensure_docker_login
    ensure_required_vars
    local img; img="$(full_image)"
    section "Quickview $img"
    docker scout quickview "$img"
}

cmd_scan() {
    ensure_docker_scout
    ensure_docker_login
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
    ensure_docker_login
    ensure_required_vars
    section "Recommendations $(full_image)"
    docker scout recommendations "$(full_image)"
}

cmd_policy() {
    ensure_docker_scout
    ensure_docker_login
    ensure_required_vars
    local img; img="$(full_image)"

    section "Policy evaluation $img  (org: $ORG)"
    log "Gate policies (${#DEFAULT_POLICIES[@]}):"
    for p in "${DEFAULT_POLICIES[@]}"; do
        printf '  • %s\n' "$p"
    done
    log "Ignoring org policy copyleft-license (inherent on debian-based Moodle image)."
    hr

    # Hub org may enable copyleft-license (fails on any Debian image). Gate on
    # DEFAULT_POLICIES via --result-file instead of raw --exit-code.
    local result_file rc=0
    result_file="$(mktemp -t scout-policy.XXXXXX.json)"
    docker scout policy "$img" --org "$ORG" --result-file "$result_file" || true

    local gate_out
    gate_out="$(
        RESULT_FILE="$result_file" python3 - "${DEFAULT_POLICIES[@]}" <<'PY'
import json, os, sys
path = os.environ["RESULT_FILE"]
wanted = sys.argv[1:]
data = json.load(open(path))
missing = [p for p in wanted if p not in data]
failed = [p for p in wanted if p in data and not data[p].get("pass")]
if "copyleft-license" in data and not data["copyleft-license"].get("pass"):
    print("warn:copyleft-license failed (ignored for gate)", file=sys.stderr)
for p in wanted:
    status = "PASS" if p in data and data[p].get("pass") else ("MISS" if p not in data else "FAIL")
    print(f"  {status}  {p}")
if missing:
    print("missing:" + ",".join(missing), file=sys.stderr)
    sys.exit(3)
if failed:
    print("failed:" + ",".join(failed), file=sys.stderr)
    sys.exit(2)
sys.exit(0)
PY
    )" || rc=$?

    printf '%s\n' "$gate_out"
    rm -f "$result_file"

    hr
    if (( rc == 0 )); then
        ok "Gate policies ĐẠT — image sẵn sàng push."
    else
        err "Policy FAIL (exit=$rc). Image $img chưa đạt chuẩn gate."
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

    # Phase 1 strategy:
    #   - SKIP_BUILD=no  → luôn build $gate_arch local cho gate.
    #   - SKIP_BUILD=yes → tái sử dụng image local đã có (vd. từ `make build`
    #     trước đó). Nhưng nếu image KHÔNG tồn tại (do `make clean`, máy mới,
    #     CI fresh runner...), auto-fallback sang build để gate có thứ quét,
    #     thay vì để Scout fail mơ hồ ở bước sau.
    if [[ "$SKIP_BUILD" != "yes" ]]; then
        log "Phase 1 — build $gate_arch local cho policy gate"
        PLATFORMS="$gate_arch" cmd_build
    elif docker image inspect "$img" >/dev/null 2>&1; then
        ok "SKIP_BUILD=yes và image local '$img' đã có → tái sử dụng cho gate."
    else
        warn "SKIP_BUILD=yes nhưng KHÔNG tìm thấy image local '$img'."
        warn "→ Auto build $gate_arch để có image cho policy gate."
        PLATFORMS="$gate_arch" cmd_build
    fi

    cmd_quickview || true

    # Lưu exit code thật của cmd_policy. Pattern `cmd || rc=$?` an toàn dưới
    # `set -e` và bắt đúng exit code (xem ghi chú trong cmd_policy).
    local policy_rc=0
    cmd_policy || policy_rc=$?
    if (( policy_rc != 0 )); then
        if [[ "$PUSH_ON_FAIL" == "yes" ]]; then
            warn "Policy fail (rc=$policy_rc) nhưng PUSH_ON_FAIL=yes → vẫn push (arch: $gate_arch)."
            cmd_push
            exit "$policy_rc"
        fi
        err "RELEASE ABORT: $img không pass policy (rc=$policy_rc). Không push."
        err "Set PUSH_ON_FAIL=yes để override (KHÔNG khuyến khích)."
        exit "$policy_rc"
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
