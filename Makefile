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

export IMAGE TAG ORG PLATFORMS BUILD_ARGS BUILDER NO_CACHE GATE_ARCH

.DEFAULT_GOAL := help

DATA_DIRS := data/moodle data/moodledata data/moodle-backups

.PHONY: help build push scan policy fix login tag-latest up down remove logs shell

help: ## Lệnh có sẵn
	@printf 'Image : %s\n' "$(IMG_FULL)"
	@printf 'Push  : %s (Scout gate → multi-arch)\n\n' "$(PLATFORMS)"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z0-9._-]+:.*?## / {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

build: ## Build local 1 arch (--no-cache, test nhanh)
	@./scripts/verify-build-manifest.sh
	DOCKER_BUILDKIT=1 docker build --no-cache --pull \
		--build-arg MOODLE_VERSION=$(MOODLE_VERSION) \
		--build-arg MOODLE_RELEASE_PREFIX=$(MOODLE_RELEASE_PREFIX) \
		--build-arg MOODLE_DOWNLOAD_URL=$(MOODLE_DOWNLOAD_URL) \
		--build-arg PHP_VERSION=$(PHP_VERSION) \
		-t $(IMG_FULL) .

push: ## Scout scan + policy gate → multi-arch push Docker Hub
	@./scripts/verify-build-manifest.sh
	@$(SCOUT) release

scan: ## Scout quickview (CVE + policy tóm tắt)
	@$(SCOUT) quickview

policy: ## Scout policy gate (7 rules)
	@$(SCOUT) policy

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
