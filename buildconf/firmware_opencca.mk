#!/bin/make -f

include env.mk

LOG = 50 ## set log level for tfa and rmm
# The RMM's per-SMC trace ("[ts_us=...] SMC_c40001b3 ... > 0 0 0 0" on the
# console for every RSI call, including every RSI_SIGNAL_SEND) is compiled in
# whenever RSI_LOG_LEVEL <= LOG_LEVEL; tf-rmm's default is 40. It costs a UART
# write per call, inside the RMM, and ruins the signalling measurements.
RSI_LOG_LEVEL = 0 ## RMM's RSI call trace (0 = off; 40 = on at LOG >= 40)
# Confidential signalling's SGI wake-up (tf-rmm conf_sig 0004/0005): a
# running peer realm gets its signal at once instead of on its next REC
# entry. The RMM retires the SGI through the redistributors, so it needs
# their address: the RK3588's GIC-600 has them at 0xfe680000, eight frames of
# 128 KiB (GICD at 0xfe600000, as in the host's DT). CONF_SIG_SGI = 0 leaves
# the base at 0 and the SGI off, i.e. delivery on next entry as before.
# CONF_SIG_TRACE prints one RMM console line per signal; keep it 0 when
# measuring, it is a UART write inside the RMM per send.
CONF_SIG_SGI = 1 ## RMM wakes a running peer realm with an SGI (0 = next REC entry only)
CONF_SIG_TRACE = 0 ## RMM console trace of every signal (0 = off)
# (strip: the "## help" comment leaves a trailing space in the value)
ifeq ($(strip $(CONF_SIG_SGI)),1)
RMM_CONF_SIG_FLAGS = -DRMM_GICR_BASE=0xfe680000 -DRMM_GICR_FRAMES=8 -DPLAT_CMN_EXTRA_MMAP_REGIONS=2
else
RMM_CONF_SIG_FLAGS = -DRMM_GICR_BASE=0x0 -DRMM_GICR_FRAMES=0
endif
DEBUG = 1 ## set debug mode for tfa and rmm
ENABLE_OPENCCA_PERF = 1 ## enable opencca perf mode
CLEAN_BUILD ?= 0 ## remove build files before build

$(info using LOG=$(LOG))
$(info using DEBUG=$(DEBUG))
$(info using ENABLE_OPENCCA_PERF=$(ENABLE_OPENCCA_PERF))
$(info using CONF_SIG_SGI=$(CONF_SIG_SGI) CONF_SIG_TRACE=$(CONF_SIG_TRACE))

.PHONY: all tfa rmm uboot clean build

all: build

.PHONY: build
build: rmm tfa ## build firmware stack
	+$(MAKE) -f $(firstword $(MAKEFILE_LIST)) uboot

# --------------------------
# TFA
# --------------------------

TFA_BUILD_TYPE := $(if $(filter 1,$(DEBUG)),debug,release)
BL31_ELF ?= $(TFA_DIR)/build/rk3588/$(TFA_BUILD_TYPE)/bl31/bl31.elf

tfa: ## build tfa
	@echo "Building TFA..."
	@echo
	@if [ "$(CLEAN_BUILD)" = "1" ]; then \
		echo "Cleaning $(TFA_DIR)..."; \
		rm -rf $(TFA_DIR)/build; \
	fi

	cd $(TFA_DIR) && \
	$(MAKE) -j$(NPROC) \
		PLAT=rk3588 \
		ENABLE_OPENCCA=1 \
		TF_A_GCC_PATH=${CROSS_COMPILE} \
		ENABLE_RME=1 \
		DEBUG=$(DEBUG) \
		LOG_LEVEL=$(LOG) \
		ENABLE_PAUTH=0 \
		ENABLE_FEAT_DIT=0 \
		ENABLE_OPENCCA_PERF=$(ENABLE_OPENCCA_PERF) \
		RME_GPT_MAX_BLOCK=0
	
	cp -rf $(BL31_ELF) $(SNAPSHOT_DIR)

tfa-clean: ## clean tfa
	-rm -r $(TFA_DIR)/build

# --------------------------
# RMM
# --------------------------

RMM_ELF ?= $(RMM_DIR)/build/$(RMM_BUILD_TYPE)/rmm.elf
RMM_BUILD_TYPE := $(if $(filter 1,$(DEBUG)),Debug,Release)
RMM_CLEAN_FLAGS :=

ifeq ($(CLEAN_BUILD),1)
    RMM_CLEAN_FLAGS += --clean-first
endif

rmm: ## build rmm
	@echo "Building RMM..."

	@if [ "$(CLEAN_BUILD)" = "1" ]; then \
		echo "Cleaning $(RMM_DIR)..."; \
		rm -rf $(RMM_DIR)/build; \
	fi

	mkdir -p $(RMM_DIR)/build

	cd $(RMM_DIR) && \
	cmake -S $(RMM_DIR)/ -B $(RMM_DIR)/build \
		-DCROSS_COMPILE=$(CROSS_COMPILE) \
		-DCMAKE_SYSTEM_PROCESSOR=aarch64 \
      		-DCMAKE_C_COMPILER=${CROSS_COMPILE}gcc \
      		-DCMAKE_ASM_COMPILER=${CROSS_COMPILE}gcc \
		-DCMAKE_OBJCOPY=${CROSS_COMPILE}objcopy \
		-DCMAKE_OBJDUMP=${CROSS_COMPILE}objdump \
		-DRMM_CONFIG=rk3588_defcfg \
		-DLOG_LEVEL=$(LOG) \
		-DRSI_LOG_LEVEL=$(RSI_LOG_LEVEL) \
		$(RMM_CONF_SIG_FLAGS) \
		-DCONF_SIG_TRACE=$(CONF_SIG_TRACE) \
		-DCMAKE_BUILD_TYPE=$(RMM_BUILD_TYPE) \
		-DENABLE_OPENCCA_PERF=$(ENABLE_OPENCCA_PERF) 
	 	
	cd $(RMM_DIR) && \
	cmake --build build $(RMM_CLEAN_FLAGS) -j$(NPROC)

	# No fallback: a missing rmm.elf must stop the build here, or U-Boot
	# below packs whatever tf-rmm.elf the snapshot held before.
	cp -rf $(RMM_ELF) $(SNAPSHOT_DIR)/tf-rmm.elf

rmm-clean: ## clean rmm
	-rm -r $(RMM_DIR)/build	

# --------------------------
# U-Boot
# --------------------------

UBOOT_ROCKCHIP_TPL := $(ASSETS_DIR)/rk3588/rk3588_ddr_lp4_2112MHz_lp5_2736MHz_v1.08.bin
UBOOT_CONFIG := $(UBOOT_DIR)/.config
UBOOT_FRAGMENT ?= $(UBOOT_DIR)/rk3588_fragment.config ## Uboot fragment
UBOOT_BIN := idbloader.img u-boot.itb u-boot-rockchip.bin u-boot-rockchip-spi.bin u-boot
UBOOT_RELEASE := $(UBOOT_BIN) $(UBOOT_CONFIG) $(UBOOT_ROCKCHIP_TPL)

uboot: ## uboot build
	@echo "Building U-Boot..."

	# debug
	@export BINMAN_DEBUG=1
	@export BINMAN_VERBOSE=3

	cd $(UBOOT_DIR) && \
	$(MAKE) rock5b-rk3588_defconfig && \
	scripts/kconfig/merge_config.sh -r -m $(UBOOT_CONFIG) $(UBOOT_FRAGMENT) && \
	$(MAKE) olddefconfig

	cd $(UBOOT_DIR) && \
	$(MAKE) -j$(NPROC) \
		CROSS_COMPILE=$(CROSS_COMPILE) \
		ROCKCHIP_TPL=$(UBOOT_ROCKCHIP_TPL) \
		BL31=$(SNAPSHOT_DIR)/bl31.elf \
		RMM=$(SNAPSHOT_DIR)/tf-rmm.elf 
	
	-cp -rf $(UBOOT_DIR)/arch/arm/dts/rk3588-rock-5b.dtb \
		$(SNAPSHOT_DIR)/uboot-rk3588-rock-5b.dtb

	-dtc -I dtb -O dts -o $(SNAPSHOT_DIR)/uboot-rk3588-rock-5b.dts \
		$(SNAPSHOT_DIR)/uboot-rk3588-rock-5b.dtb > /dev/null 2>&1 &

	# The FIT must carry the RMM: CONFIG_RMM_ELF_ADJUST_BASE in the fragment
	# and RMM= above are what put it there, and a U-Boot without it boots a
	# host with no realm world.
	grep -q -a "atf-rmm" $(UBOOT_DIR)/u-boot.itb || \
		{ echo "ERROR: $(UBOOT_DIR)/u-boot.itb carries no RMM image" >&2; exit 1; }

	cd $(UBOOT_DIR) && cp -rf $(UBOOT_RELEASE) $(SNAPSHOT_DIR)

	@echo "$$(grep -a -o 'U-Boot 20[0-9.]*-g[0-9a-f]* ([^)]*)' $(UBOOT_DIR)/u-boot.itb | head -1) -> $(SNAPSHOT_DIR)"

uboot-clean: ## clean uboot
	cd $(UBOOT_DIR) && $(MAKE) distclean

uboot-menuconfig:  ## run menuconfig for uboot
	cd $(UBOOT_DIR) && \
		scripts/kconfig/merge_config.sh -r $(UBOOT_CONFIG) $(UBOOT_FRAGMENT)

	$(MAKE) menuconfig

	diff -uw .config.old .config



clean: tfa-clean rmm-clean uboot-clean ## clean all

