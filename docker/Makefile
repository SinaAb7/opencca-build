#!/usr/bin/make -f

DOCKER_DIR := $(dir $(realpath $(firstword $(MAKEFILE_LIST))))

DOCKER = docker
# Stable per-clone project name (same folder => same name; different folder => different name)

PROJECT := opencca-$(shell echo "$(realpath $(DOCKER_DIR))" | sha1sum | cut -c1-8)

DOCKER_COMPOSE := $(DOCKER) compose -p $(PROJECT) -f $(DOCKER_DIR)/docker-compose.yml

SRC_DIR = /opencca
SHELL_HISTORY = $(DOCKER_DIR)/.bash_history $(DOCKER_DIR)/.fish_history
CACHE_DIR = $(DOCKER_DIR)/.cache
SHELL := /bin/bash

VERSION := latest
SERVICE_URL := ghcr.io/opencca/opencca-build

SERVICE = opencca-build

.PHONY: help
help:
	@echo "Usage: make [target]"
	@echo "Targets:"
	@echo "  build         - Build the Docker image locally"
	@echo "  pull          - Pull a prebuilt image"
	@echo "  start         - Start the interactive development container"
	@echo "  enter         - Enter the running container"
	@echo "  run CMD='...' - Run a command inside the container"
	@echo "  stop          - Stop the container"
	@echo "  clean         - Remove the container and unused images"

.PHONY: setup
setup:
	touch $(SHELL_HISTORY)
	mkdir -p $(CACHE_DIR)

.PHONY: pull
pull: setup
	$(DOCKER) pull $(SERVICE_URL):$(VERSION)

.PHONY: build
build: setup
	-@docker image rm $(SERVICE_URL) &> /dev/null
	$(DOCKER_COMPOSE) build $(SERVICE)

.PHONY: start
start: setup
	$(DOCKER_COMPOSE) up -d $(SERVICE)

.PHONY: enter
enter:
	$(DOCKER_COMPOSE) exec $(SERVICE) bash

.PHONY: run
run:
	$(DOCKER_COMPOSE) run --rm $(SERVICE) $(CMD)

.PHONY: stop
stop:
	-$(DOCKER_COMPOSE) stop $(SERVICE)

.PHONY: clean
clean: SYSTEM=0
clean:
	$(DOCKER) rm -f $(SERVICE) $(SERVICE_URL) &> /dev/null ||  true
	$(DOCKER) volume rm $$(docker volume ls -qf dangling=true) &> /dev/null || true
	[[ $(SYSTEM) == 1 ]] && $(DOCKER) system prune -f || true

# For CI
.PHONY: release
release: RELEASE_BUILD_DATE=$(shell date -u +%Y-%m-%dT%H:%M:%SZ)
release: RELEASE_VCS_REF=$(shell git rev-parse --short HEAD)
release: RELEASE_VERSION=$(shell git describe --tags --always )
release:
	IMAGE_TAG=latest \
	RELEASE_BUILD_DATE=$(RELEASE_BUILD_DATE) \
	RELEASE_VCS_REF=$(RELEASE_VCS_REF) \
	RELEASE_VERSION=$(RELEASE_VERSION) \
	$(DOCKER_COMPOSE) build $(SERVICE)

	$(DOCKER) tag $(SERVICE_URL):latest $(SERVICE_URL):$(RELEASE_VERSION)
	$(DOCKER) push $(SERVICE_URL):$(RELEASE_VERSION)
	$(DOCKER) push $(SERVICE_URL):latest
