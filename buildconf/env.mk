.THIS_MAKEFILE := $(lastword $(MAKEFILE_LIST))
.THIS_DIR :=  $(realpath $(dir $(.THIS_MAKEFILE)))
ROOT_DIR := $(.THIS_DIR)/../..

KVMTOOL_DIR ?= $(ROOT_DIR)/kvmtool
LINUX_DIR ?= $(ROOT_DIR)/linux
LINUX_GUEST_DIR ?=$(ROOT_DIR)/linux-guest
TFA_DIR ?= $(ROOT_DIR)/trusted-firmware-a
RMM_DIR ?= $(ROOT_DIR)/tf-rmm
DTC_DIR ?= $(ROOT_DIR)/dtc
UBOOT_DIR ?= $(ROOT_DIR)/u-boot
RKBIN_DIR ?= $(ROOT_DIR)/rkbin
ASSETS_DIR ?= $(ROOT_DIR)/opencca-assets

OPENCCA_BUILD_DIR ?= $(ROOT_DIR)/opencca-build
OPENCCA_FLASH_DIR ?= $(ROOT_DIR)/opencca-flash

BUILDROOT_DIR ?= $(ROOT_DIR)/buildroot

export SNAPSHOT_DIR ?= $(ROOT_DIR)/snapshot

DEBOS_DIR ?= $(ROOT_DIR)/debian-image-recipes

NPROC ?= $(shell nproc)
export MAKEFLAGS += -j$(NPROC)


help: ## Print this help message
	@echo "Available make targets for $(firstword $(MAKEFILE_LIST)):"

	@# Print all targets with ## in help text
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z0-9_-]+:.*##/ \
		{printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	
	@echo ""
	@echo "Available make variables for $(firstword $(MAKEFILE_LIST))"
	@# Print all variables with ## in help text
	@awk 'BEGIN {FS = "(:=|\\+=|\\?=|=)|##"} \
		/^(export[ \t]+)?[A-Z0-9_-]+[[:space:]]*(:=|\?=||\+=|=).*##/ \
		{printf "  \033[33m%-25s\033[0m %-3s \033[32m%s\033[0m \n", $$1, $$2, $$3}' $(MAKEFILE_LIST)

	@echo ""
	@# Print all variables without ## in help text
	@awk 'BEGIN {FS = "(:=|\\+=|\\?=|=)"} \
		/^(export[ \t]+)?[A-Z0-9_-]+[[:space:]]*(:=|\?=|\+=|=)/ && !/##/ \
		{printf "  \033[33m%-25s\033[0m %-3s \033[32m%s\033[0m \n", $$1, $$2, $$3}' $(MAKEFILE_LIST)

		
print-vars:
	@$(foreach v, $(.VARIABLES), \
        $(if $(filter-out environment% default automatic, $(origin $v)), \
            $(info $v=$($v)) \
        ) \
    )
