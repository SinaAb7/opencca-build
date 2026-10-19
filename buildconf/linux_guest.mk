#!/usr/bin/make -f
include env.mk
override LINUX_DIR := $(LINUX_DIR)/../linux-guest
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
		-e VIRT_DRIVERS \
		-e ARM_CCA_GUEST \
		-e IVSHMEM_NOTIFY \
		-e TUN \
		-e MACVLAN \
		-e MACVTAP \
		-e VHOST_MENU \
		-e VHOST \
		-e VHOST_NET \
		-e VHOST_VSOCK \
		-e SECURITY_LANDLOCK \
		-e OVERLAY_FS \
		-e FUSE_FS \
		-e VIRTIO_FS \
		-e VSOCKETS \
		-e VIRTIO_VSOCKETS \
		-e VSOCKETS_LOOPBACK \
		-e R8169 \
		-e NF_CONNTRACK \
		-e NF_NAT \
		-e NETFILTER_XTABLES \
		-e IP_NF_IPTABLES \
		-e IP_NF_NAT \
		-e IP_NF_TARGET_MASQUERADE
# NF_* / IP_NF_* built in (defconfig makes them modules, and the guest image
# installs no modules): the diode VM masquerades the workload VM's traffic out
# of its passed-through NIC onto the lab LAN (net-bench.sh diode,
# docs/net-bench.md), which needs iptables' MASQUERADE in the kernel.
# AF_VSOCK and its virtio transport (net/vmw_vsock/virtio_transport.c with
# the diode patches) for vsock over the diode; the loopback transport is what
# vsock-bench.sh measures it against. Built in: the image loads no modules.
# R8169 built in (defconfig makes it a module): the board's RTL8125 passed
# through with vfio-pci (docs/nic-passthrough.md) then comes up without a
# modprobe, which the guest image is not set up for.
# The options from VIRT_DRIVERS onward enable the diode data path, as the
# main repo's shrinkwrap build does (config/cca-3world-diode.yaml):
# the ivshmem_notify cross-VM
# doorbell (under VIRT_DRIVERS, off in defconfig, as is the CCA guest driver
# next to it), the vhost-net datapath the diode VM's backend hands the rings
# to, and virtio-fs (built in, FUSE_FS=m in defconfig would make it a module)
# for the share served by the diode VM's virtio_fs_backend.
# VHOST_VSOCK: vsock-backend.sh --vhost hands the vsock device's queues to
# the diode VM's kernel the same way (vsock-bench.sh diode --vhost).
# SECURITY_LANDLOCK: OpenShell's sandbox (openshell-sandbox, the workload
# VM) refuses to start without Landlock ABI 3 or newer; SECURITY=y and
# "landlock" in the default LSM list are already in defconfig. The
# emulator's guest kernel has it (config/cca-3world-diode.yaml).
# OVERLAY_FS built in (a module in defconfig, and the image loads none):
# Docker in the OpenClaw image (docker-install.sh; the one-VM baseline and
# the diode launcher's sandbox container) then uses overlay2, so a
# container starts on a view of its image instead of vfs's full copy.
# VHOST_NET depends on (TUN || !TUN) && (TAP || !TAP). MACVTAP=m
# selects TAP=m and caps VHOST_NET at m; promote MACVLAN/MACVTAP to y.

define check_vhost_net
	@for symbol in TUN TAP VHOST VHOST_NET VHOST_VSOCK SECURITY_LANDLOCK OVERLAY_FS; do \
		grep -qx "CONFIG_$$symbol=y" $(KERNEL_CONFIG) || { \
			echo "ERROR: CONFIG_$$symbol must be built in (diode backends: TUN/MACVLAN/MACVTAP, VHOST_NET, VHOST_VSOCK; OpenShell sandbox: LANDLOCK; Docker: OVERLAY_FS); check fragment overrides." >&2; \
			exit 1; \
		}; \
	done
endef

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
	$(check_vhost_net)

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

	$(check_vhost_net)
	-cp -rf $(LINUX_DIR)/.config $(SNAPSHOT_DIR)/rk3588-kernel-config

.PHONY: kernel
kernel: kconfig ## build linux kernel
	@echo "Building kernel"
	+$(MAKE) -C $(LINUX_DIR) KBUILD_IMAGE="arch/arm64/boot/Image" \
		LOCALVERSION=$(LOCALVERSION) 

	-cp -rf $(LINUX_DIR)/arch/arm64/boot/Image $(SNAPSHOT_DIR)/Image-guest

.PHONY: devel
devel: ## Build kernel without re-generating .config first (devel)
	+$(MAKE) -C $(LINUX_DIR) KBUILD_IMAGE=arch/arm64/boot/Image \
		LOCALVERSION=$(LOCALVERSION) 

	-cp -rf $(LINUX_DIR)/arch/arm64/boot/Image $(SNAPSHOT_DIR)/Image-guest


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
