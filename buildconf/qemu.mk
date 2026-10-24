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
# linux-io-uring: the disk's aio=io_uring engine (run-realm.sh --thin-disk).
#        Asked for explicitly so that a container without liburing-dev:arm64
#        fails here, not on the board when the VM starts. The board host
#        (trixie) has liburing.so.2 - its qemu-system-arm depends on it.
# no linux-aio: aio=native would link libaio.so.1 from the bookworm container,
#        and trixie only has libaio.so.1t64 (the time64 rename), so such a
#        binary does not load on the board at all. io_uring is the engine.
QEMU_CONFIGURE_FLAGS ?= \
	--cross-prefix=$(QEMU_CROSS_PREFIX) \
	--target-list=aarch64-softmmu \
	--enable-kvm \
	--enable-slirp \
	--enable-tools \
	--enable-linux-io-uring \
	--disable-linux-aio \
	--disable-docs \
	--disable-werror \
	--disable-sdl \
	--disable-gtk

QEMU_BINARY := $(QEMU_BUILD_DIR)/qemu-system-aarch64
IVSHMEM_SERVER := $(QEMU_BUILD_DIR)/contrib/ivshmem-server/ivshmem-server

.PHONY: all configure build clean stale-check
all: build

# The flags QEMU was last configured with, so that a change to
# QEMU_CONFIGURE_FLAGS reconfigures an existing build directory instead of
# being ignored: configure used to run only when build.ninja was missing, so
# a flag added later (--enable-linux-io-uring) silently never reached the
# binary. The stamp is rewritten only when its content differs, and
# build.ninja depends on it; QEMU's configure handles an already configured
# directory itself (it drops meson-private and runs meson setup again).
CONFIGURE_STAMP := $(QEMU_BUILD_DIR)/.configure-flags
.PHONY: force
$(CONFIGURE_STAMP): force
	@mkdir -p $(QEMU_BUILD_DIR)
	@printf '%s\n' '$(QEMU_CONFIGURE_FLAGS)' | cmp -s - $@ || \
		{ echo "qemu.mk: configure flags changed - reconfiguring"; printf '%s\n' '$(QEMU_CONFIGURE_FLAGS)' > $@; }

$(QEMU_BUILD_DIR)/build.ninja: $(CONFIGURE_STAMP)
	cd $(QEMU_BUILD_DIR) && $(QEMU_DIR)/configure $(QEMU_CONFIGURE_FLAGS)

# meson bakes the absolute source path into the build directory (build.ninja,
# config-host.mak, the pyvenv, and meson-private/coredata.dat, which is a
# pickle and cannot be rewritten), so a build directory configured under a
# different name for QEMU_DIR is unusable: ninja re-runs meson from the old
# path and fails with "meson: not found". Renaming the checkout (qemu-diode ->
# qemu-vmm) left exactly that behind. Drop such a directory and configure
# again instead of failing.
stale-check:
	@if [ -d $(QEMU_BUILD_DIR) ] && \
	    [ "$$(sed -n 's/^SRC_PATH=//p' $(QEMU_BUILD_DIR)/config-host.mak 2>/dev/null)" != \
	      "$$(cd $(QEMU_DIR) && pwd)" ]; then \
		echo "qemu.mk: $(QEMU_BUILD_DIR) was configured for another source directory - reconfiguring"; \
		rm -rf $(QEMU_BUILD_DIR); \
	fi

configure: stale-check $(QEMU_BUILD_DIR)/build.ninja ## configure qemu for the board

build: configure ## build qemu-system-aarch64 and ivshmem-server
	ninja -C $(QEMU_BUILD_DIR) -j$(NPROC) qemu-system-aarch64 contrib/ivshmem-server/ivshmem-server
	cp $(QEMU_BINARY) $(SNAPSHOT_DIR)/qemu-system-aarch64
	cp $(IVSHMEM_SERVER) $(SNAPSHOT_DIR)/ivshmem-server

clean: ## remove the qemu build directory
	-rm -rf $(QEMU_BUILD_DIR)
