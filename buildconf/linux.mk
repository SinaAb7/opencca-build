#!/usr/bin/make -f
include env.mk

SHELL := /bin/bash
LOCALVERSION ?= -opencca-wip ## kernel version suffix

.PHONY: build
build: kernel ## see kernel

# ---------------
# Kernel Build
# ---------------

KERNEL_CONFIG := $(LINUX_DIR)/.config
KERNEL_FRAGMENT := $(LINUX_DIR)/rk3588_fragment.config ## kconfig fragment
KERNEL_KCONFIG += \
		-e WLAN \
		-e WLAN_VENDOR_BROADCOM \
		-m BRCMUTIL \
		-m BRCMFMAC \
		-e BRCMFMAC_PROTO_BCDC \
		-e BRCMFMAC_PROTO_MSGBUF \
		-e BRCMFMAC_USB \
		-e WLAN_VENDOR_REALTEK \
		-m RTW89 \
		-m RTW89_CORE \
		-m RTW89_PCI \
		-m RTW89_8825B \
		-m RTW89_8852BE \
		-m BINFMT_MISC \
		-d RELR \
		-d CPU_IDLE \
		-d ARM_PSCI_CPUIDLE \
		-d ARM_PSCI_CPUIDLE_DOMAIN \
		-e PHY_ROCKCHIP_NANENG_COMBO_PHY \
		--set-val STMMAC_ETH y \
		--set-val STMMAC_PLATFORM y \
		--set-val DWMAC_ROCKCHIP y \
		--set-val R8169 y \
		--set-val DRM y \
		--set-val DRM_ROCKCHIP y \
		--set-val DRM_PANFROST y \
		--set-val DRM_PANTHOR y \
   		--set-val TUN y \
		--set-val NETFILTER y \
    	--set-val NETFILTER_ADVANCED y \
    	--set-val NETFILTER_XTABLES y \
    	--set-val NF_CONNTRACK y \
    	--set-val NF_NAT y \
    	--set-val IP_NF_IPTABLES y \
    	--set-val IP_NF_FILTER y \
    	--set-val IP_NF_NAT y \
    	--set-val NETFILTER_XT_NAT y \
    	--set-val NETFILTER_XT_MATCH_CONNTRACK y \
    	--set-val NETFILTER_XT_TARGET_MASQUERADE y \
		--set-val NF_TABLES y \
        --set-val NF_TABLES_INET y \
        --set-val NFT_CT y \
        --set-val NFT_NAT y \
        --set-val NFT_MASQ y
		

.PHONY: kconfig
 # $(KERNEL_FRAGMENT) ## Generate .config file	
kconfig:
	echo "test"
	# Step 1: generate base config
	+$(MAKE) -C $(LINUX_DIR) ARCH=$(ARCH) KBUILD_CC=$(KBUILD_CC) defconfig

	# Step 2: apply scripted overrides
	cd $(LINUX_DIR) && $(LINUX_DIR)/scripts/config $(KERNEL_KCONFIG)

	# Step 3: apply fragment (this will override previous settings if there's conflict)
	cd $(LINUX_DIR) && $(LINUX_DIR)/scripts/kconfig/merge_config.sh \
		-O $(LINUX_DIR) \
		-m \
		.config \
		$(KERNEL_FRAGMENT)

	# Step 4: finalize
	+$(MAKE) -C $(LINUX_DIR) ARCH=$(ARCH) olddefconfig

	# Optionally: save
	-cp -f $(LINUX_DIR)/.config $(SNAPSHOT_DIR)/rk3588-kernel-config

.PHONY: kconfig_old
kconfig_old: $(KERNEL_FRAGMENT) ## Generate .config file	

    # generate .config
	+$(MAKE) -C $(LINUX_DIR) ARCH=$(ARCH) KBUILD_CC=$(KBUILD_CC) defconfig

    # apply rk3588 settings
	cd $(LINUX_DIR) && $(LINUX_DIR)/scripts/config $(KERNEL_KCONFIG)

    # apply fragment
	cd $(LINUX_DIR) && $(LINUX_DIR)/scripts/kconfig/merge_config.sh \
		$(KERNEL_CONFIG) \
		$(KERNEL_FRAGMENT)

	-cp -rf $(LINUX_DIR)/.config $(SNAPSHOT_DIR)/rk3588-kernel-config

.PHONY: kernel
kernel: kconfig ## build linux kernel
	@echo "Building kernel"
	+$(MAKE) -C $(LINUX_DIR) KBUILD_IMAGE="arch/arm64/boot/Image" \
		LOCALVERSION=$(LOCALVERSION) 

	-cp -rf $(LINUX_DIR)/arch/arm64/boot/dts/rockchip/rk3588-rock-5b-plus.dtb $(SNAPSHOT_DIR)
	-cp -rf $(LINUX_DIR)/arch/arm64/boot/Image $(SNAPSHOT_DIR)
	-dtc -I dtb -O dts -o $(SNAPSHOT_DIR)/rk3588-rock-5b-plus.dts \
		$(SNAPSHOT_DIR)/rk3588-rock-5b-plus.dtb > /dev/null 2>&1 &

.PHONY: devel
devel: ## Build kernel without re-generating .config first (devel)
	+$(MAKE) -C $(LINUX_DIR) KBUILD_IMAGE=arch/arm64/boot/Image \
		LOCALVERSION=$(LOCALVERSION) 

	-cp -rf $(LINUX_DIR)/arch/arm64/boot/dts/rockchip/rk3588-rock-5b-plus.dtb $(SNAPSHOT_DIR)
	-cp -rf $(LINUX_DIR)/arch/arm64/boot/Image $(SNAPSHOT_DIR)
	-dtc -I dtb -O dts -o $(SNAPSHOT_DIR)/rk3588-rock-5b-plus.dts \
		$(SNAPSHOT_DIR)/rk3588-rock-5b-plus.dtb > /dev/null 2>&1 &



# ---------------
# Debian package
# ---------------

BUILD_TIMESTAMP := $$(date +%Y-%m-%d_%H-%M-%S)
DEBIAN_RELEASE_DIR ?= $(LINUX_DIR)/../linux-release/$(BUILD_TIMESTAMP)_$(KERNEL_VERSION) ## output dir for deb build
KERNEL_VERSION = $(shell make -sC $(LINUX_DIR) kernelversion)$(LOCALVERSION)
KDEB_PKGVERSION ?= $(KERNEL_VERSION)


.PHONY: debian
debian: kconfig ## Build kernel and package into .deb archive (requires initial kconfig)
	+$(MAKE) -C $(LINUX_DIR) \
		CROSS_COMPILE=$(CROSS_COMPILE) \
		KBUILD_IMAGE=arch/arm64/boot/Image \
		ARCH=$(ARCH) \
		LOCALVERSION=$(LOCALVERSION) \
		KDEB_PKGVERSION=$(KDEB_PKGVERSION) \
		deb-pkg

    # XXX: deb-pkg creates *.deb files in parent
    # directory of linux dir. We move these to their own folder.
	mkdir -p $(DEBIAN_RELEASE_DIR)
	mv $(LINUX_DIR)/../linux-upstream* $(DEBIAN_RELEASE_DIR)
	mv $(LINUX_DIR)/../linux-*.deb $(DEBIAN_RELEASE_DIR)
	@echo "Files moved to $(DEBIAN_RELEASE_DIR)"
	ls -al $(DEBIAN_RELEASE_DIR)/

.PHONY: menuconfig
menuconfig: ## Launch kernel menuconfig
	cd $(LINUX_DIR) && \
		cp -f .config .config.pre-menuconfig

	cd $(LINUX_DIR) && \
		$(MAKE) menuconfig

	cd $(LINUX_DIR) && \
		scripts/diffconfig .config.pre-menuconfig .config 

.PHONY: clean
clean: ## Clean kernel build
	+$(MAKE) -C $(LINUX_DIR) clean
	+$(MAKE) -C $(LINUX_DIR) mrproper
