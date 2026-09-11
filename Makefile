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

.PHONY: help build push inspect-manifest scan policy cves-critical fix login tag-latest up down remove logs shell \
	deploys new plan apply output ssh destroy

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

# Một khách hàng = một thư mục dưới terraform/deployments/ = một state riêng.
# Tên khách đi thẳng trên dòng lệnh: make apply horizonschool-aws
# Hậu tố -aws / -gcp quyết định cloud, nên không lệnh nào cần biến.
# Xem terraform/README.md.

TF ?= terraform

DEPLOYS  := $(notdir $(patsubst %/,%,$(wildcard terraform/deployments/*/)))
TF_VERBS := deploys new plan apply output ssh destroy
DEPLOY   := $(filter-out $(TF_VERBS),$(MAKECMDGOALS))
TF_DIR    = terraform/deployments/$(DEPLOY)

# Tên khách xuất hiện như một goal nên make cần một target cho nó. Chỉ sinh từ thư
# mục có thật, để gõ sai tên vẫn báo lỗi thay vì im lặng không làm gì.
$(DEPLOYS):
	@:
.PHONY: $(DEPLOYS)

# `new` là lệnh duy nhất nhận tên chưa tồn tại, nên chỉ nó cần catch-all, và chỉ khi
# nó thực sự có trên dòng lệnh — nếu định nghĩa vô điều kiện thì mọi target gõ sai
# đều lặng lẽ thành no-op.
ifneq ($(filter new,$(MAKECMDGOALS)),)
%:
	@:
endif

define need_deploy
	@test -n "$(DEPLOY)" || { \
		printf 'Thiếu tên deployment. Ví dụ: make %s horizonschool-aws\n' '$@'; \
		printf 'Đang có:\n'; printf '  %s\n' $(DEPLOYS); \
		exit 1; }
	@test $(words $(DEPLOY)) -eq 1 || { \
		printf 'Mỗi lệnh một deployment, không phải: %s\n' '$(DEPLOY)'; \
		exit 1; }
	@test -d "$(TF_DIR)" || { \
		printf 'Không có deployment %s\n' '$(DEPLOY)'; \
		printf '  make new %s\n' '$(DEPLOY)'; \
		exit 1; }
	@test -f "$(TF_DIR)/terraform.tfvars" || { \
		printf 'Thiếu %s/terraform.tfvars\n' '$(TF_DIR)'; \
		exit 1; }
endef

deploys: ## Terraform: liệt kê deployment và domain hiện tại
	@scripts/tf-deployments.sh list

new: ## Terraform: tạo khách mới — make new truong-b-gcp
	@scripts/tf-deployments.sh new "$(DEPLOY)" "$(CLOUD)"

# Backend của Terraform không nhận biến, nên nếu không truyền credential của
# deployment vào bằng biến môi trường thì backend sẽ rơi về profile mặc định của máy —
# và state của khách này đi vào account của người khác. TF_ENV bảo đảm backend và
# provider luôn dùng chung một danh tính.
TF_ENV = eval "$$(scripts/tf-deployments.sh env $(DEPLOY))" &&

plan: ## Terraform: xem trước, không đụng gì — make plan <ten>
	$(call need_deploy)
	@scripts/tf-deployments.sh backend $(DEPLOY)
	@$(TF_ENV) $(TF) -chdir=$(TF_DIR) init -input=false
	@$(TF_ENV) $(TF) -chdir=$(TF_DIR) plan

apply: ## Terraform: dựng hoặc cập nhật — make apply <ten>
	$(call need_deploy)
	@scripts/tf-deployments.sh backend $(DEPLOY)
	@$(TF_ENV) $(TF) -chdir=$(TF_DIR) init -input=false -upgrade
	@$(TF_ENV) $(TF) -chdir=$(TF_DIR) apply

output: ## Terraform: in output kể cả mật khẩu — make output <ten>
	$(call need_deploy)
	@$(TF_ENV) $(TF) -chdir=$(TF_DIR) output -json | \
		python3 -c 'import json,sys; [print("%-24s %s" % (k, v["value"])) for k, v in json.load(sys.stdin).items()]'

# break-glass.pem nằm cạnh state nên phải chạy từ trong thư mục. Ưu tiên nó thay vì
# ssh_command: output đó được ghi vào state lúc apply, nên các stack apply trước lần
# tách module vẫn còn mang đường dẫn cũ cho tới lần apply kế tiếp.
ssh: ## Terraform: vào VM — make ssh <ten>
	$(call need_deploy)
	@$(TF_ENV) cd $(TF_DIR) && if [ -f break-glass.pem ]; then \
		ssh -i break-glass.pem admin@$$($(TF) output -raw public_ip); \
	else \
		eval "$$($(TF) output -raw ssh_command)"; \
	fi

destroy: ## Terraform: xoá hạ tầng (mất toàn bộ data Moodle của khách đó) — make destroy <ten>
	$(call need_deploy)
	@$(TF_ENV) $(TF) -chdir=$(TF_DIR) destroy
