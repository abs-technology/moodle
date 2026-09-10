# versions.lock = single source of truth for versions/tag

-include versions.lock

IMAGE     ?= abstechnology/moodle-standard
TAG       ?= $(DOCKER_TAG)
ORG       ?= abstechnology
PLATFORMS ?= linux/amd64,linux/arm64
BUILDER   ?= scout-builder
NO_CACHE  ?= yes
SCOUT     := ./scripts/utils/docker-scout.sh
IMG_FULL  := $(IMAGE):$(TAG)

# Scout nhận BUILD_ARGS dạng "KEY=VAL KEY2=VAL2"
BUILD_ARGS ?= MOODLE_VERSION=$(MOODLE_VERSION) MOODLE_RELEASE_PREFIX=$(MOODLE_RELEASE_PREFIX) MOODLE_DOWNLOAD_URL=$(MOODLE_DOWNLOAD_URL) PHP_VERSION=$(PHP_VERSION)

# Gate arch = native host (tránh QEMU chậm khi scan)
HOST_ARCH := $(shell uname -m)
ifneq (,$(filter $(HOST_ARCH),arm64 aarch64))
    GATE_ARCH ?= linux/arm64
else
    GATE_ARCH ?= linux/amd64
endif

# Pin BuildKit / SBOM (chỉ dùng nếu ATTESTATIONS=full)
BUILDKIT_IMAGE ?= moby/buildkit:v0.32.2
SBOM_SCANNER   ?= docker/buildkit-syft-scanner:latest
# none = mặc định: 1 image cho Hub + Marketplace (không SBOM/provenance → hết cảnh báo Go)
# full = bật attestation (Scout supply-chain); Marketplace Artifact Analysis sẽ flag Go/containerd
ATTESTATIONS   ?= none

export IMAGE TAG ORG PLATFORMS BUILD_ARGS BUILDER NO_CACHE GATE_ARCH
export BUILDKIT_IMAGE SBOM_SCANNER ATTESTATIONS

.DEFAULT_GOAL := help

DATA_DIRS := data/moodle data/moodledata data/moodle-backups

TF ?= terraform

# terraform.tfvars carries project_id / acme_email và không được commit.
define tf_require_tfvars
	@test -f terraform/$(1)/terraform.tfvars || { \
		printf 'Thiếu terraform/%s/terraform.tfvars\n' '$(1)'; \
		printf '  cp terraform/%s/terraform.tfvars.example terraform/%s/terraform.tfvars\n' '$(1)' '$(1)'; \
		exit 1; }
endef

.PHONY: help build push inspect-manifest scan policy cves-critical fix login tag-latest up down remove logs shell \
	gcp gcp-destroy gcp-ssh aws aws-destroy aws-ssh

help: ## Lệnh có sẵn
	@printf 'Image : %s\n' "$(IMG_FULL)"
	@printf 'Push  : %s (Scout gate → multi-arch, ATTESTATIONS=%s)\n' "$(PLATFORMS)" "$(ATTESTATIONS)"
	@printf 'Note  : 1 lần make push → 1 image dùng cho Hub + Marketplace\n'
	@printf '       raw Critical OK nếu fixable C/H PASS — docs/SECURITY-EXCEPTIONS.md\n\n'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z0-9._-]+:.*?## / {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

build: ## Build local 1 arch (--no-cache, test nhanh)
	@./scripts/verify-build-manifest.sh
	DOCKER_BUILDKIT=1 docker build --no-cache --pull \
		--build-arg MOODLE_VERSION=$(MOODLE_VERSION) \
		--build-arg MOODLE_RELEASE_PREFIX=$(MOODLE_RELEASE_PREFIX) \
		--build-arg MOODLE_DOWNLOAD_URL=$(MOODLE_DOWNLOAD_URL) \
		--build-arg PHP_VERSION=$(PHP_VERSION) \
		-t $(IMG_FULL) .

push: ## Scout gate + multi-arch push (1 image — Hub & Marketplace)
	@./scripts/verify-build-manifest.sh
	@docker buildx rm $(BUILDER) >/dev/null 2>&1 || true
	@$(SCOUT) release
	@printf '\nManifest (không nên có unknown/unknown attestation):\n'
	@$(MAKE) --no-print-directory inspect-manifest

inspect-manifest: ## Xem manifest (attestation = unknown/unknown)
	@docker buildx imagetools inspect $(IMG_FULL)

scan: ## Scout quickview (CVE + policy tóm tắt; raw C ≠ release blocker)
	@$(SCOUT) quickview

policy: ## Scout release gate (fixable C/H; ignores copyleft)
	@$(SCOUT) policy

cves-critical: ## Liệt kê raw Critical CVEs (review; xem docs/SECURITY-EXCEPTIONS.md)
	@docker scout cves $(IMG_FULL) --only-severity critical --details

fix: ## Scout gợi ý fix CVE / base image
	@$(SCOUT) recommendations

login: ## docker login
	@docker login

tag-latest: ## Gắn tag latest (multi-arch manifest)
	@docker buildx imagetools create $(IMG_FULL) --tag $(IMAGE):latest

up: ## docker compose up -d
	@docker compose up -d

down: ## docker compose down
	@docker compose down

remove: ## Dừng stack + xoá data Moodle + volume MariaDB
	@docker compose down -v
	@mkdir -p $(DATA_DIRS)
	@docker run --rm \
		-v "$(CURDIR)/data/moodle:/wipe/moodle" \
		-v "$(CURDIR)/data/moodledata:/wipe/moodledata" \
		-v "$(CURDIR)/data/moodle-backups:/wipe/moodle-backups" \
		alpine:3.20 \
		sh -c 'find /wipe/moodle /wipe/moodledata /wipe/moodle-backups -mindepth 1 -delete'
	@touch data/moodle/.gitkeep data/moodledata/.gitkeep
	@printf 'Đã xoá sạch: %s + volume mariadb_data\n' "$(DATA_DIRS)"

logs: ## Xem log moodle
	@docker compose logs -f moodle

shell: ## Vào shell container moodle
	@docker compose exec moodle bash

# VPC mới, không mở 22 ra internet, VM chỉ pull image từ Docker Hub — xem terraform/README.md
gcp: ## Terraform: VPC mới + VM Debian 13 trên GCP + deploy Moodle
	$(call tf_require_tfvars,gcp)
	@$(TF) -chdir=terraform/gcp init -input=false -upgrade
	@$(TF) -chdir=terraform/gcp apply

gcp-ssh: ## SSH vào VM GCP qua IAP tunnel
	@eval "$$($(TF) -chdir=terraform/gcp output -raw ssh_command)"

gcp-destroy: ## Xoá hạ tầng GCP (mất toàn bộ data Moodle)
	$(call tf_require_tfvars,gcp)
	@$(TF) -chdir=terraform/gcp destroy

aws: ## Terraform: VPC mới + VM Debian 13 trên AWS + deploy Moodle
	$(call tf_require_tfvars,aws)
	@$(TF) -chdir=terraform/aws init -input=false -upgrade
	@$(TF) -chdir=terraform/aws apply

aws-ssh: ## SSH vào VM AWS qua SSM Session Manager
	@eval "$$($(TF) -chdir=terraform/aws output -raw ssh_command)"

aws-destroy: ## Xoá hạ tầng AWS (mất toàn bộ data Moodle)
	$(call tf_require_tfvars,aws)
	@$(TF) -chdir=terraform/aws destroy
