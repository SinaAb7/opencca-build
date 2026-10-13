#!/usr/bin/make -f

# NVIDIA OpenShell for the board's guests: the sandbox (workload VM) and the
# supervisor, gateway, CLI and conformance tool (diode VM), cross-built for
# aarch64 from board/openshell by the main repo's tools/build-openshell.sh
# through manifest/build_openshell.sh - one build, shared with the emulator.
#
# Output: snapshot/openshell/<component>/..., the tree a guest keeps at
# /opt/openshell, plus snapshot/openshell/host/openshell, a CLI for the build
# machine. The guest image builds (manifest/build_guest_fs*.sh) run the same
# script themselves, so a plain `build_all.sh openshell` is for a manual
# rebuild and transfer.
#
# Needs: the build machine's rustup mounted at /opt/rustup (read-only) and
# /opt/cargo - docker-compose.yml does that; a container started before that
# mount existed has to be recreated with ./manifest/container.sh - with the
# toolchain OpenShell pins (rust-toolchain.toml) and the
# aarch64-unknown-linux-gnu target installed, and the main repo's tools/ at
# /tools (also docker-compose.yml). cmake and the aarch64 cross g++ are in
# the container image.
#
# OPENSHELL_DIR
# SNAPSHOT_DIR
include env.mk

OPENSHELL_DIR ?= $(ROOT_DIR)/openshell
OPENSHELL_BUILD ?= $(ROOT_DIR)/manifest/build_openshell.sh

.PHONY: all build clean
all: build

build: ## cross-build every OpenShell component into snapshot/openshell/
	$(OPENSHELL_BUILD)

clean: ## remove the OpenShell build state (tmp/openshell-{stage,target})
	-rm -rf $(ROOT_DIR)/tmp/openshell-stage $(ROOT_DIR)/tmp/openshell-target
