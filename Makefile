COREOS_RELEASE_CHANNEL ?= stable
COREOS_RELEASES_URL := https://coreos.com/releases/releases-$(COREOS_RELEASE_CHANNEL).json

COREOS_VERSION ?=
ifneq ($(origin COREOS_VERSION), undefined)
	COREOS_VERSION = $(shell \
		curl -s ${COREOS_RELEASES_URL} | \
			jq -r  keys_unsorted[0])
endif

NVIDIA_MATURIRY ?= official
NVIDIA_VERSIONS_URL := https://raw.githubusercontent.com/aaronp24/nvidia-versions/master/nvidia-versions.txt

NVIDIA_DRIVER_VERSION ?=
ifneq ($(origin NVIDIA_DRIVER_VERSION), undefined)
	NVIDIA_DRIVER_VERSION = $(shell \
		curl -s $(NVIDIA_VERSIONS_URL) | \
			grep -i "current $(NVIDIA_MATURIRY)" | \
			cut -d' ' -f3-)
endif

KERNEL_VERSION = $(shell \
	curl -s ${COREOS_RELEASES_URL} | \
		jq -r .[\"${COREOS_VERSION}\"].major_software.kernel[0])

# Environment
WORKDIR := $(PWD)

# Docker configuration
DOCKER_ORG ?=
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

build: validate
	echo "Building Docker Image ..." && \
	docker build \
		--build-arg COREOS_VERSION=$(COREOS_VERSION) \
		--build-arg NVIDIA_DRIVER_VERSION=$(NVIDIA_DRIVER_VERSION) \
		--build-arg KERNEL_VERSION=$(KERNEL_VERSION) \
		--tag $(DOCKER_REGISTRY)/$(DOCKER_ORG)/$(DOCKER_REPOSITORY):$(COREOS_VERSION) \
		--file $(WORKDIR)/Dockerfile . \

push: build
	if [ "$(DOCKER_USERNAME)" != "" ]; then \
		docker login -u="$(DOCKER_USERNAME)" -p="$(DOCKER_PASSWORD)"; \
	fi; \
	docker push $(DOCKER_REGISTRY)/$(DOCKER_ORG)/$(DOCKER_REPOSITORY):$(COREOS_VERSION)

.PHONY: validate build push
