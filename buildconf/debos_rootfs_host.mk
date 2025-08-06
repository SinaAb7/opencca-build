#!/usr/bin/make -f

# DEBOS_DIR
include env_x86.mk

OSPACK_IMAGE = $(DEBOS_DIR)/out/ospack-debian-arm64-trixie.tar.gz
OSPACK_YAML = $(DEBOS_DIR)/opencca-ospack-debian.yaml
DOWNLOAD_PREBUILT = $(DEBOS_DIR)/download-rock5b-opencca-artifacts.sh
PREBUILT_DIR = $(DEBOS_DIR)/prebuilt

CPUS = $(shell expr $(shell nproc) - 1)
MEMORY = 6Gb

.PHONY: debos clean

build: rk3588 ## build root file system
 
$(OSPACK_IMAGE): $(OSPACK_YAML)
	sudo chmod 777 /dev/kvm || exit 1
	cd $(DEBOS_DIR) && \
	mkdir -p out && \
    debos --cpus=$(CPUS) --memory=$(MEMORY) --artifactdir=out -t architecture:arm64 opencca-ospack-debian.yaml || exit 1

rk3588: $(OSPACK_IMAGE) download
	sudo chmod 777 /dev/kvm || exit 1
	cd $(DEBOS_DIR) && \
	debos --cpus=$(CPUS) --memory=$(MEMORY) --artifactdir=out -t architecture:arm64 \
		-t platform:rock5b-rk3588 opencca-image-rockchip-rk3588.yaml || exit 1

# Delete PREBUILT_DIR to re-download
$(PREBUILT_DIR)/.downloaded:
	mkdir -p $(PREBUILT_DIR)
	bash $(DOWNLOAD_PREBUILT) || exit 1
	touch $@

.PHONY: download
download: $(PREBUILT_DIR)/.downloaded

clean: ## clean
	rm -r $(PREBUILT_DIR)