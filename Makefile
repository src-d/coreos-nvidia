# Linux Container release channel (stable, beta or alpha)
COREOS_RELEASE_CHANNEL ?= stable
COREOS_RELEASES_URL := https://coreos.com/releases/releases-$(COREOS_RELEASE_CHANNEL).json

# Linux Container version, if empty the last available version for the given
# release channel will be use making a request to the release feed.
COREOS_VERSION ?=
ifneq ($(origin COREOS_VERSION), undefined)
	COREOS_VERSION = $(shell \
		curl -s ${COREOS_RELEASES_URL} | \
			jq -r  keys_unsorted[0])
endif

NVIDIA_MATURIRY ?= official
NVIDIA_VERSIONS_URL := https://raw.githubusercontent.com/aaronp24/nvidia-versions/master/nvidia-versions.txt

# NVIDIA Driver version, if empty the last available version will be used. The
# version is retrieve from https://github.com/aaronp24/nvidia-versions/
NVIDIA_DRIVER_VERSION ?=
ifneq ($(origin NVIDIA_DRIVER_VERSION), undefined)
	NVIDIA_DRIVER_VERSION = $(shell \
		curl -s $(NVIDIA_VERSIONS_URL) | \
			grep -i "current $(NVIDIA_MATURIRY)" | \
				cut -d' ' -f3-)
endif

# Kernel version used in the given `COREOS_VERSION`, if empty is retrieve from
# the CoreOS release feed.
KERNEL_VERSION = $(shell \
	curl -s ${COREOS_RELEASES_URL} | \
		jq -r .[\"${COREOS_VERSION}\"].major_software.kernel[0])

KERNEL_TAG := $(shell echo ${KERNEL_VERSION} | sed -e 's/\(\.0\)*$$//g')

# Environment
WORKDIR := $(PWD)

# Docker configuration
DOCKER_ORG ?= srcd
DOCKER_REPOSITORY ?= coreos-nvidia
DOCKER_USERNAME ?=
DOCKER_PASSWORD ?=
DOCKER_REGISTRY ?= docker.io

validate:
	@if [ -z "$(COREOS_RELEASE_CHANNEL)" ]; then \
		echo "COREOS_RELEASE_CHANNEL cannot be empty."; \
		exit 1; \
	fi;
	@if [ -z "$(COREOS_VERSION)" ]; then \
		echo "COREOS_VERSION cannot be empty, automatic detection has failed."; \
		exit 1; \
	fi;
	@if [ -z "$(NVIDIA_DRIVER_VERSION)" ]; then \
		echo "NVIDIA_DRIVER_VERSION cannot be empty, automatic detection has failed."; \
		exit 1; \
	fi;
	@if [ -z "$(KERNEL_VERSION)" ]; then \
		echo "KERNEL_VERSION cannot be empty, automatic detection has failed."; \
		exit 1; \
	fi;
	@if [ -z "$(DOCKER_ORG)" ]; then \
		echo "DOCKER_ORG cannot be empty."; \
		exit 1; \
	fi;

pull: validate
	echo "Trying to pull previous build ..."
	-docker pull $(DOCKER_REGISTRY)/$(DOCKER_ORG)/$(DOCKER_REPOSITORY):$(COREOS_VERSION)

build: validate
	echo "Building Docker Image ..." && \
	docker build \
		--cache-from $(DOCKER_REGISTRY)/$(DOCKER_ORG)/$(DOCKER_REPOSITORY):$(COREOS_VERSION) \
		--build-arg COREOS_RELEASE_CHANNEL=$(COREOS_RELEASE_CHANNEL) \
		--build-arg COREOS_VERSION=$(COREOS_VERSION) \
		--build-arg NVIDIA_DRIVER_VERSION=$(NVIDIA_DRIVER_VERSION) \
		--build-arg KERNEL_VERSION=$(KERNEL_VERSION) \
		--build-arg KERNEL_TAG=$(KERNEL_TAG) \
		--tag $(DOCKER_REGISTRY)/$(DOCKER_ORG)/$(DOCKER_REPOSITORY):$(COREOS_VERSION) \
		--file $(WORKDIR)/Dockerfile . \

push: build
	if [ "$(DOCKER_USERNAME)" != "" ]; then \
		docker login --username="$(DOCKER_USERNAME)" --password-stdin <<< "$(DOCKER_PASSWORD)"; \
	fi; \
	docker push $(DOCKER_REGISTRY)/$(DOCKER_ORG)/$(DOCKER_REPOSITORY):$(COREOS_VERSION)

.PHONY: validate build push
