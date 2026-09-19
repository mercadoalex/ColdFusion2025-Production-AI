CUR_DIR := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))

# ── Configuration ─────────────────────────────────────────────────────────────
REGISTRY      ?= ghcr.io/$(shell git config user.name | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
IMAGE_NAME    ?= cf-training
RELEASE       ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo dev)
FULL_TAG      := $(REGISTRY)/$(IMAGE_NAME):$(RELEASE)
LATEST_TAG    := $(REGISTRY)/$(IMAGE_NAME):latest

# ── Course image tags ──────────────────────────────────────────────────────────
# :fundamentals — Course 1 (Modules 1-4, basic to intermediate, single VM)
# :advanced     — Course 2 (Modules 5-8, DevOps/AI, multi-VM with Ollama + cf-prod)
# :dev          — active development tag (always points at latest build)
FUNDAMENTALS_TAG := $(REGISTRY)/$(IMAGE_NAME):fundamentals
ADVANCED_TAG     := $(REGISTRY)/$(IMAGE_NAME):advanced

# Ollama node image — separate image, separate registry path
OLLAMA_IMAGE     ?= cf-ollama
OLLAMA_TAG       := $(REGISTRY)/$(OLLAMA_IMAGE):latest
OLLAMA_MODEL     ?= phi3:mini

# ColdFusion installer ZIP (place in downloads/ — exact filename from Adobe)
CF_INSTALLER  ?= $(CUR_DIR)/downloads/ColdFusion_2025_WWEJ_linux64.zip

# Lab user (matches iximiuz platform convention)
LAB_USER      ?= laborant
ARKADE_BIN    ?= /usr/local/bin

# Build-time versions (keep in sync with iximiuz labs-playgrounds Makefile)
BTOP_VERSION      ?= 1.4.4
CFSSL_VERSION     ?= 1.6.5
WEBSOCAT_VERSION  ?= 1.14.0
COMMANDBOX_VERSION ?= 6.3.4
LUCEE_VERSION     ?= 7.0.4.34

# ── Phony targets ─────────────────────────────────────────────────────────────
.PHONY: all build push tag-latest run shell clean help \
        check-installer check-docker check-registry downloads \
        build-ollama push-ollama

all: build

# ── Build ─────────────────────────────────────────────────────────────────────
## build: Build the rootfs OCI image (stub mode if no CF installer found)
build: check-docker
	@echo "\033[0;32mBuilding $(FULL_TAG)...\033[0m"
	@if [ ! -f "$(CF_INSTALLER)" ]; then \
	  echo "\033[0;33mWARNING: No CF installer at $(CF_INSTALLER).\033[0m"; \
	  echo "\033[0;33m  Building in STUB mode. Place the ZIP in downloads/.\033[0m"; \
	fi
	docker build \
		--progress plain \
		--platform linux/amd64 \
		--build-arg LAB_USER=$(LAB_USER) \
		--build-arg ARKADE_BIN_DIR=$(ARKADE_BIN) \
		--build-arg BTOP_VERSION=$(BTOP_VERSION) \
		--build-arg CFSSL_VERSION=$(CFSSL_VERSION) \
		--build-arg WEBSOCAT_VERSION=$(WEBSOCAT_VERSION) \
		--build-arg COMMANDBOX_VERSION=$(COMMANDBOX_VERSION) \
		--build-arg LUCEE_VERSION=$(LUCEE_VERSION) \
		-t $(FULL_TAG) \
		-f $(CUR_DIR)/rootfs/Dockerfile \
		$(CUR_DIR)
	@echo "\033[0;32mBuild complete: $(FULL_TAG)\033[0m"

## build-with-cf: Build with a real ColdFusion installer (errors if not found)
build-with-cf: check-installer check-docker
	$(MAKE) build CF_INSTALLER=$(CF_INSTALLER)

# ── Push ──────────────────────────────────────────────────────────────────────
## push: Push the image to the registry
push: build check-registry
	@echo "\033[0;32mPushing $(FULL_TAG)...\033[0m"
	docker push $(FULL_TAG)
	@echo "\033[0;32mDone!\033[0m"

## tag-latest: Tag the current release as :latest and push
tag-latest: push
	docker tag $(FULL_TAG) $(LATEST_TAG)
	docker push $(LATEST_TAG)

## tag-fundamentals: Tag the current :dev build as :fundamentals (Course 1) and push
tag-fundamentals: check-registry
	docker tag $(REGISTRY)/$(IMAGE_NAME):dev $(FUNDAMENTALS_TAG)
	docker push $(FUNDAMENTALS_TAG)
	@echo "\033[0;32mTagged as fundamentals: $(FUNDAMENTALS_TAG)\033[0m"

## tag-advanced: Tag the current :dev build as :advanced (Course 2) and push
tag-advanced: check-registry
	docker tag $(REGISTRY)/$(IMAGE_NAME):dev $(ADVANCED_TAG)
	docker push $(ADVANCED_TAG)
	@echo "\033[0;32mTagged as advanced: $(ADVANCED_TAG)\033[0m"

## build-ollama: Build the Ollama AI node image (pulls phi3:mini at build time — needs internet)
build-ollama: check-docker
	@echo "\033[0;32mBuilding $(OLLAMA_TAG)...\033[0m"
	@echo "\033[0;33mNOTE: phi3:mini (~2.3 GB) will be downloaded during build.\033[0m"
	docker build \
		--progress plain \
		--platform linux/amd64 \
		--build-arg OLLAMA_MODEL="$(OLLAMA_MODEL)" \
		-t $(OLLAMA_TAG) \
		-f $(CUR_DIR)/rootfs/Dockerfile.ollama \
		$(CUR_DIR)
	@echo "\033[0;32mBuild complete: $(OLLAMA_TAG)\033[0m"

## push-ollama: Build and push the Ollama AI node image to the registry
push-ollama: build-ollama check-registry
	@echo "\033[0;32mPushing $(OLLAMA_TAG)...\033[0m"
	docker push $(OLLAMA_TAG)
	@echo "\033[0;32mDone: $(OLLAMA_TAG)\033[0m"

# ── Local testing ─────────────────────────────────────────────────────────────
## run: Run the image locally as a container (for quick smoke-testing)
## NOTE: This is NOT how iximiuz runs it (they use microVMs). Use for filesystem
##       inspection only; systemd will not boot properly in a container.
run: build
	docker run --rm -it \
		--name cf-training-test \
		-p 8500:8500 \
		-p 8888:8888 \
		$(FULL_TAG) \
		/bin/bash

## shell: Open a shell in the built image without starting services
shell: build
	docker run --rm -it \
		--name cf-training-shell \
		--entrypoint /bin/bash \
		$(FULL_TAG)

## inspect: Show image layers and size
inspect: build
	docker inspect $(FULL_TAG) | jq '.[0] | {Id, Architecture, Os, Size: (.Size / 1024 / 1024 | floor | tostring + " MB"), Layers: (.RootFS.Layers | length)}'
	@echo ""
	docker history $(FULL_TAG) --format "table {{.Size}}\t{{.CreatedBy}}"

# ── Helpers ───────────────────────────────────────────────────────────────────
## update-playground: Patch playground.yaml with the current image tag
update-playground:
	@sed -i.bak \
	  "s|oci://ghcr.io/.*cf-training:.*|oci://$(FULL_TAG)|g" \
	  $(CUR_DIR)/playground/playground.yaml
	@echo "Updated playground.yaml → oci://$(FULL_TAG)"

## downloads: Show how to download the CF installer
downloads:
	@echo ""
	@echo "Download Adobe ColdFusion 2025 Trial Edition (ZIP installer) from:"
	@echo "  https://helpx.adobe.com/coldfusion/using/download-coldfusion.html"
	@echo "  → 'Download Adobe ColdFusion Trial Edition (2025 release)'"
	@echo "  → Select: Linux 64-bit ZIP installer"
	@echo ""
	@echo "The file will be named:  ColdFusion_2025_WWEJ_linux64.zip"
	@echo "Place it at:             $(CF_INSTALLER)"
	@echo ""
	@echo "Then run:  make build-with-cf"
	@echo ""

# ── Checks ────────────────────────────────────────────────────────────────────
check-docker:
	@command -v docker >/dev/null 2>&1 || \
	  (echo "\033[0;31mERROR: docker not found. Install Docker Desktop or Docker Engine.\033[0m"; exit 1)

check-installer:
	@if [ ! -f "$(CF_INSTALLER)" ]; then \
	  echo "\033[0;31mERROR: ColdFusion ZIP not found at: $(CF_INSTALLER)\033[0m"; \
	  echo "Run 'make downloads' for instructions."; \
	  exit 1; \
	fi

check-registry:
	@if echo "$(REGISTRY)" | grep -q 'your-org\|your-name\|<'; then \
	  echo "\033[0;31mERROR: Set REGISTRY to your actual OCI registry.\033[0m"; \
	  echo "  Example:  make push REGISTRY=ghcr.io/myname"; \
	  exit 1; \
	fi

# ── Clean ─────────────────────────────────────────────────────────────────────
## clean: Remove local image and build artifacts
clean:
	docker rmi $(FULL_TAG) $(LATEST_TAG) 2>/dev/null || true
	@echo "Cleaned."

# ── Help ──────────────────────────────────────────────────────────────────────
## help: Show this help
help:
	@grep -E '^## ' $(MAKEFILE_LIST) | sed 's/## /  /'
