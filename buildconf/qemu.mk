#!/usr/bin/make -f

# Diode-CCA QEMU for the board host: qemu-system-aarch64, plus the
# ivshmem-server its ivshmem-doorbell device connects to.
#
# The result is dynamically linked. The board's host rootfs installs Debian's
# qemu-system-arm, which brings every library it needs (glib, pixman, slirp,
# libfdt, zlib).
#
# QEMU_DIR
# SNAPSHOT_DIR
include env.mk

QEMU_BUILD_DIR ?= $(QEMU_DIR)/build
QEMU_CROSS_PREFIX ?= aarch64-linux-gnu-

# kvm:   the board runs QEMU as a KVM VMM only.
# slirp: -netdev user, which QEMU no longer carries in-tree.
# tools: meson only descends into contrib/, where ivshmem-server lives,
#        when tools are enabled.
QEMU_CONFIGURE_FLAGS ?= \
	--cross-prefix=$(QEMU_CROSS_PREFIX) \
	--target-list=aarch64-softmmu \
	--enable-kvm \
	--enable-slirp \
	--enable-tools \
	--disable-docs \
	--disable-werror \
	--disable-sdl \
	--disable-gtk

QEMU_BINARY := $(QEMU_BUILD_DIR)/qemu-system-aarch64
IVSHMEM_SERVER := $(QEMU_BUILD_DIR)/contrib/ivshmem-server/ivshmem-server

.PHONY: all configure build clean
all: build

$(QEMU_BUILD_DIR)/build.ninja:
	mkdir -p $(QEMU_BUILD_DIR)
	cd $(QEMU_BUILD_DIR) && $(QEMU_DIR)/configure $(QEMU_CONFIGURE_FLAGS)

configure: $(QEMU_BUILD_DIR)/build.ninja ## configure qemu for the board

build: configure ## build qemu-system-aarch64 and ivshmem-server
	ninja -C $(QEMU_BUILD_DIR) -j$(NPROC) qemu-system-aarch64 contrib/ivshmem-server/ivshmem-server
	cp $(QEMU_BINARY) $(SNAPSHOT_DIR)/qemu-system-aarch64
	cp $(IVSHMEM_SERVER) $(SNAPSHOT_DIR)/ivshmem-server

clean: ## remove the qemu build directory
	-rm -rf $(QEMU_BUILD_DIR)
