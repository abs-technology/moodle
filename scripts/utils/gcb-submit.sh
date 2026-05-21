#!/usr/bin/env bash
# Submit Cloud Build với tag = tên branch hiện tại.
#
# Quy ước tag:
#   - Default: TAG = branch name (sau khi strip prefix `moodle-core-`)
#       moodle-core-5-2-plus  → 5-2-plus
#       moodle-core-4-5-11    → 4-5-11
#   - --full-branch: TAG = nguyên branch name (moodle-core-5-2-plus)
#   - --with-timestamp: thêm hậu tố -YYYYMMDD-HHMM
#   - TAG=<custom>: override hoàn toàn
#
# Usage:
#   ./scripts/utils/gcb-submit.sh                     # tag = 5-2-plus
#   ./scripts/utils/gcb-submit.sh --full-branch       # tag = moodle-core-5-2-plus
#   ./scripts/utils/gcb-submit.sh --with-timestamp    # tag = 5-2-plus-20260520-2315
#   TAG=v1.0.0 ./scripts/utils/gcb-submit.sh          # tag = v1.0.0
#   AR_REGION=us-central1 AR_REPO=lms ./scripts/utils/gcb-submit.sh

set -euo pipefail

cd "$(dirname "$0")/../.."

AR_REGION="${AR_REGION:-asia-southeast1}"
AR_REPO="${AR_REPO:-moodle-marketplace}"
IMAGE="${IMAGE:-moodle-standard}"

BRANCH=$(git rev-parse --abbrev-ref HEAD)
BRAND="${BRANCH#moodle-core-}"   # strip prefix nếu có

case "${1:-}" in
    --full-branch)    TAG="${TAG:-$BRANCH}" ;;
    --with-timestamp) TAG="${TAG:-${BRAND}-$(date +%Y%m%d-%H%M)}" ;;
    *)                TAG="${TAG:-$BRAND}" ;;
esac

PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
if [[ -z "$PROJECT_ID" ]]; then
    echo "ERROR: gcloud project chưa set. Chạy: gcloud config set project <PROJECT_ID>" >&2
    exit 1
fi

# Multi-arch default. Override: PLATFORMS=linux/amd64 ./scripts/utils/gcb-submit.sh
PLATFORMS="${PLATFORMS:-linux/amd64,linux/arm64}"

# BuildKit registry cache (default ON). Force fresh: NO_CACHE=true make gcp-build
NO_CACHE_FLAG="${NO_CACHE:-}"

FULL_IMAGE="${AR_REGION}-docker.pkg.dev/${PROJECT_ID}/${AR_REPO}/${IMAGE}:${TAG}"

CACHE_INFO="ON (cache=${FULL_IMAGE}-buildcache)"
[[ "$NO_CACHE_FLAG" == "true" ]] && CACHE_INFO="OFF (--no-cache, fresh build)"

cat <<EOF
=====================================================================
Submit Cloud Build (Gen 2, region=${AR_REGION}):
  Project   : $PROJECT_ID
  Branch    : $BRANCH
  Image tag : $FULL_IMAGE
  Platforms : $PLATFORMS
  Cache     : $CACHE_INFO
=====================================================================
EOF

## --region: bắt buộc để dùng Cloud Build Gen 2 execution environment
##   (startup nhanh 10-30s, network IO mạnh, default pool toàn region).
##   Không có flag này → fallback về global pool (Gen 1, chậm).
##   Region phải KHỚP với AR_REGION để giảm network latency push lên AR.
##
## Custom delimiter `^@^` (xem `gcloud topic escaping`) — cần khi giá trị
## substitution chứa dấu `,` (vd: _PLATFORMS=linux/amd64,linux/arm64).
gcloud builds submit \
    --region="${AR_REGION}" \
    --config=cloudbuild.yaml \
    --substitutions="^@^_AR_REGION=${AR_REGION}@_AR_REPO=${AR_REPO}@_IMAGE=${IMAGE}@_BRANCH=${BRANCH}@_TAG=${TAG}@_PLATFORMS=${PLATFORMS}@_NO_CACHE=${NO_CACHE_FLAG}" \
    .
