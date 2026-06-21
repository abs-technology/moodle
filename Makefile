# =============================================================================

-include versions.lock

# ---- Configurable variables ------------------------------------------------ #
IMAGE        ?= abstechnology/moodle-standard
TAG          ?= $(DOCKER_TAG)
PLATFORMS    ?= linux/amd64,linux/arm64
ORG          ?= abstechnology
DOCKERFILE   ?= Dockerfile
CONTEXT      ?= .
SEVERITY     ?= critical,high
BUILD_ARGS   ?= MOODLE_VERSION=$(MOODLE_VERSION) MOODLE_RELEASE_PREFIX=$(MOODLE_RELEASE_PREFIX) MOODLE_DOWNLOAD_URL=$(MOODLE_DOWNLOAD_URL) PHP_VERSION=$(PHP_VERSION)
SKIP_BUILD   ?= no
PUSH_ON_FAIL ?= no

# Build determinism (default: NO cache, local builder only) ---------------- #
# NO_CACHE: rebuild from scratch mỗi lần để luôn pull base + security patches
#   mới nhất từ bookworm-security. Override: make build NO_CACHE=no (dev test).
# BUILDER:  buildx builder LOCAL (driver=docker-container). KHÔNG dùng Docker
#   Build Cloud (`--driver cloud`); script sẽ recreate builder nếu phát hiện
#   driver khác.
NO_CACHE       ?= yes
BUILDER        ?= scout-builder

# Pin BuildKit + SBOM scanner để Go runtime ≥ 1.21.0 (CVE-2023-24531).
# External scanners (Google Artifact Analysis, Trivy) sẽ KHÔNG còn flag Go
# toolchain cũ nhúng trong SBOM/provenance attestation.
BUILDKIT_IMAGE ?= moby/buildkit:latest
SBOM_SCANNER   ?= docker/buildkit-syft-scanner:1.11.0

# ATTESTATIONS: full | provenance-only | none
#   full          (default): SBOM + Provenance (cần cho Scout supply-chain policy)
#   provenance-only: tắt SBOM (loại syft Go binary khỏi metadata)
#   none          : tắt cả 2 — dùng khi external scanner chặn Go CVE
ATTESTATIONS   ?= full

# ---- Google Cloud Build (Marketplace VM Solution test) -------------------- #
# Build Dockerfile qua Cloud Build + scan bằng Container Analysis — chính
# scanner Google Cloud Marketplace dùng để validate image partner submit.
# Tag = `brand` (branch minus prefix `moodle-core-`).
AR_REGION      ?= asia-southeast1
AR_REPO        ?= moodle-marketplace
AR_IMAGE       ?= moodle-standard
GCB_OPTS       ?=

# ---- Auto-detect host arch cho GATE phase --------------------------------- #
# Phase gate (make build) build NATIVE 1 arch của host để tránh QEMU emulation
# (Apple Silicon build linux/amd64 chậm 3-5x). Phase push mới làm multi-arch.
# Override: make build GATE_ARCH=linux/amd64
HOST_ARCH := $(shell uname -m)
ifneq (,$(filter $(HOST_ARCH),arm64 aarch64))
    GATE_ARCH ?= linux/arm64
else
    GATE_ARCH ?= linux/amd64
endif

# ---- Internal -------------------------------------------------------------- #
SCOUT        := ./scripts/utils/docker-scout.sh
IMG_FULL     := $(IMAGE):$(TAG)

export IMAGE TAG PLATFORMS GATE_ARCH ORG DOCKERFILE CONTEXT
export ONLY_SEVERITY=$(SEVERITY)
export BUILD_ARGS SKIP_BUILD PUSH_ON_FAIL
export NO_CACHE BUILDER BUILDKIT_IMAGE SBOM_SCANNER ATTESTATIONS
export AR_REGION AR_REPO AR_IMAGE

# ---- Help (default) -------------------------------------------------------- #
.DEFAULT_GOAL := help

.PHONY: help
help: ## Hiển thị danh sách target
	@printf '\033[1mABS Technology Moodle — Makefile\033[0m\n\n'
	@printf 'Image      : %s\n'   "$(IMG_FULL)"
	@printf 'Host arch  : %s\n'   "$(HOST_ARCH)"
	@printf 'Gate arch  : %s  \033[2m(build local, gate Scout — native, KHÔNG emulation)\033[0m\n' "$(GATE_ARCH)"
	@printf 'Push archs : %s  \033[2m(multi-arch khi push lên registry)\033[0m\n' "$(PLATFORMS)"
	@printf 'Builder    : %s  \033[2m(driver=docker-container, build LOCAL — không dùng cloud)\033[0m\n' "$(BUILDER)"
	@printf 'No-cache   : %s  \033[2m(rebuild from scratch để luôn có patches mới nhất)\033[0m\n' "$(NO_CACHE)"
	@BRANCH=$$(git rev-parse --abbrev-ref HEAD 2>/dev/null); \
	BRAND="$${BRANCH#moodle-core-}"; \
	printf 'GCP target : %s-docker.pkg.dev/<PROJECT>/%s/%s:%s\n\n' "$(AR_REGION)" "$(AR_REPO)" "$(AR_IMAGE)" "$$BRAND"
	@printf '\033[1mTargets:\033[0m\n'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z0-9._-]+:.*?## / {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@printf '\n\033[1mOverride:\033[0m make <target> TAG=... PLATFORMS=... GATE_ARCH=... NO_CACHE=no\n'

# ---- Main workflow --------------------------------------------------------- #
.PHONY: verify-versions
verify-versions: ## Kiểm tra versions.lock khớp Dockerfile/Makefile/compose
	@./scripts/verify-build-manifest.sh

.PHONY: build
build: verify-versions ## Build $(GATE_ARCH) local (--load) + Scout quickview + policy gate (KHÔNG push)
	@PLATFORMS=$(GATE_ARCH) $(SCOUT) build
	@$(SCOUT) quickview || true
	@$(SCOUT) policy

.PHONY: push
push: ## Re-verify policy + rebuild multi-arch + push lên Docker Hub
	@SKIP_BUILD=yes $(SCOUT) release

# ---- Scout commands -------------------------------------------------------- #
.PHONY: scan
scan: ## Quickview Scout — 7 policy + CVE summary
	@$(SCOUT) quickview

.PHONY: policy
policy: ## Chỉ chạy 7 policy gate — exit ≠ 0 nếu fail
	@$(SCOUT) policy

.PHONY: cves
cves: ## Liệt kê CVE chi tiết theo SEVERITY (mặc định critical,high)
	@$(SCOUT) scan

.PHONY: fix
fix: ## Gợi ý nâng cấp base image / fix CVE
	@$(SCOUT) recommendations

# ---- Registry helpers ------------------------------------------------------ #
.PHONY: login
login: ## Login Docker Hub
	@docker login

.PHONY: push-only
push-only: ## Push tag hiện tại lên registry (KHÔNG build, KHÔNG gate — cẩn thận)
	@$(SCOUT) push

.PHONY: tag-latest
tag-latest: ## Tag $(IMG_FULL) → :latest (giữ manifest multi-arch)
	@docker buildx imagetools create $(IMG_FULL) --tag $(IMAGE):latest
	@printf '\033[32m[ ok ]\033[0m Tagged → %s:latest\n' "$(IMAGE)"

.PHONY: info
info: ## Xem image local + manifest registry
	@printf '\033[1m== Local images ==\033[0m\n'
	@docker images $(IMAGE) --format 'table {{.Repository}}:{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}' 2>/dev/null || true
	@printf '\n\033[1m== Registry %s ==\033[0m\n' "$(IMG_FULL)"
	@docker buildx imagetools inspect $(IMG_FULL) 2>/dev/null || echo "(image chưa có trên registry)"

# ---- Maintenance ----------------------------------------------------------- #
.PHONY: clean
clean: ## Xóa image test (*-scout-test) + dangling
	@docker images "$(IMAGE)" --format "{{.Repository}}:{{.Tag}}" | grep -E "scout-test$$" | xargs -r docker rmi -f 2>/dev/null || true
	@docker image prune -f
	@printf '\033[32m[ ok ]\033[0m Đã dọn\n'

# ---- Google Cloud Platform Build (Marketplace test) ------------------------ #
# Build Dockerfile qua GCP Cloud Build service + scan bằng Container Analysis
# (chính scanner Google Marketplace dùng).
.PHONY: gcp-build
gcp-build: ## Build qua Google Cloud Build + scan Container Analysis (tag=brand)
	@IMAGE=$(AR_IMAGE) AR_REGION=$(AR_REGION) AR_REPO=$(AR_REPO) \
		./scripts/utils/gcb-submit.sh $(GCB_OPTS)

.PHONY: gcp-build-ts
gcp-build-ts: ## Như `make gcp-build` nhưng tag có timestamp (tránh ghi đè)
	@$(MAKE) gcp-build GCB_OPTS=--with-timestamp

.PHONY: gcp-build-full
gcp-build-full: ## Như `make gcp-build` nhưng tag = nguyên branch (moodle-core-5-2-1-plus)
	@$(MAKE) gcp-build GCB_OPTS=--full-branch

.PHONY: gcp-build-fresh
gcp-build-fresh: ## Force --no-cache trên Cloud Build (pull fresh apt security patches)
	@NO_CACHE=true $(MAKE) gcp-build

.PHONY: gcp-show-iam
gcp-show-iam: ## Hiển thị IAM policy hiện tại của Artifact Registry repo
	@gcloud artifacts repositories get-iam-policy $(AR_REPO) --location=$(AR_REGION)

.PHONY: gcp-build-info
gcp-build-info: ## Hiển thị tag/image sẽ build qua GCP Cloud Build (preview, không submit)
	@BRANCH=$$(git rev-parse --abbrev-ref HEAD); \
	BRAND="$${BRANCH#moodle-core-}"; \
	PROJECT=$$(gcloud config get-value project 2>/dev/null || echo '<PROJECT_ID-chưa-set>'); \
	printf '\033[1m== GCP Cloud Build target ==\033[0m\n'; \
	printf '  Project   : %s\n' "$$PROJECT"; \
	printf '  Branch    : %s\n' "$$BRANCH"; \
	printf '  Brand→Tag : %s\n' "$$BRAND"; \
	printf '  Image     : %s-docker.pkg.dev/%s/%s/%s:%s\n' \
		"$(AR_REGION)" "$$PROJECT" "$(AR_REPO)" "$(AR_IMAGE)" "$$BRAND"

# ---- Compose helpers ------------------------------------------------------- #
.PHONY: up
up: ## docker compose up -d (stack moodle local)
	@docker compose up -d

.PHONY: down
down: ## docker compose down
	@docker compose down

.PHONY: logs
logs: ## Tail logs container moodle
	@docker compose logs -f moodle

.PHONY: shell
shell: ## Mở bash trong container moodle
	@docker compose exec moodle bash
