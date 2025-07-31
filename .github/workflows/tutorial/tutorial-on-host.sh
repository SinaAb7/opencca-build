#!/usr/bin/env bash
set -euo pipefail
readonly SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

#
# Reproducible Getting Started Tutorial
# This runs in a CI build.
#
check_binary_installed() {
  if ! command -v "$1" &> /dev/null; then
    echo "Error: '$1' is not installed or not in PATH." >&2
    exit 1
  fi
}

# Prerequisites
check_binary_installed docker
check_binary_installed git
check_binary_installed repo
check_binary_installed make

if [ ! -e /dev/kvm ]; then
  echo "Info: KVM not available. Cannot build rootfs"
fi

# --------------------------------
# Download repos
# --------------------------------
MANIFEST_BRANCH=opencca/systex25
MANIFEST_FILE=systex25.xml

CUR_DIR=$(pwd)
PROJ_ROOT=$CUR_DIR/opencca

mkdir -p opencca opencca/snapshot
cd opencca

repo init -u https://github.com/opencca/opencca-manifest.git \
    -b $MANIFEST_BRANCH -m $MANIFEST_FILE \
    --depth=10  # depth=10 to limit history

# -j5 run on 5 cores
repo sync --all -j5 --fetch-submodules  


# --------------------------------
# Pull and start container
# --------------------------------

cd opencca-build/docker
make pull

make start

# Now you would run `make enter`
# Since we run this in a scirpt, we do `make run-script` instead
# since we are not interactive

# Continue in the container: tutorial-in-container.sh
make run-script SCRIPT=$SCRIPT_DIR/tutorial-in-container.sh






