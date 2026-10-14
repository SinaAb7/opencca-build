#!/usr/bin/env bash
set -euo pipefail

#
# Wrapper that bulk builds all components
# See individual components in buildconf/* 
# for fine grained builds
#
# Run:
#   build_all.sh
#
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
cd "$SCRIPT_DIR"
ENV_FILE=$SCRIPT_DIR/../buildconf/env_x86.mk

# Get environment from makefile
eval "$(make -f $ENV_FILE print-vars | sed 's/^/export /')" &>/dev/null || true

# Colors
COLOR="\e[35m"
RESET="\e[0m"

# Paths
BUILDCONF_DIR=$OPENCCA_BUILD_DIR/buildconf
LOG_DIR="$SCRIPT_DIR/build_log"
LOG_FILE="$LOG_DIR/stdout.log"

build_all=(
    build_kvmtool
    build_qemu
    build_linux
    build_linux_guest
    build_modules
    build_firmware
    transfer_binaries
)

build_kvmtool=(
    build_kvmtool
)
build_qemu=(
    build_qemu
)
build_linux=(
    build_linux
   # build_modules
)
build_linux_guest=(
    build_linux_guest
    build_modules
)
build_firmware=(
    build_firmware
)

build_modules=(
    build_modules
)
# OpenShell is not in build_all: it needs the build machine's rustup mounted
# (see buildconf/openshell.mk), which older containers lack.
build_openshell=(
    build_openshell
)
declare -A build_status

trap 'echo "Error on line $LINENO with exit code $?" && exit 1' ERR SIGINT

function log() { echo -e "${COLOR}$1${RESET}"; }

# Build Functions:
function build_kvmtool {
    cd $BUILDCONF_DIR
    make -f kvmtool.mk build
}

function build_qemu {
    cd $BUILDCONF_DIR
    make -f qemu.mk build
}

function build_openshell {
    cd $BUILDCONF_DIR
    make -f openshell.mk build
}

function build_linux {
    cd $BUILDCONF_DIR
    make -f linux.mk kernel && \
    make -f linux.mk debian
}
#function build_linux_guest {
 #   cd $BUILDCONF_DIR
  #  ./build-linux-guest-script.sh 
#}
function build_linux_guest {
    cd $BUILDCONF_DIR
    make -f linux_guest.mk kernel && \
    make -f linux_guest.mk debian
}
function build_firmware {
    cd $BUILDCONF_DIR
    make -f firmware_opencca.mk clean
    make -f firmware_opencca.mk build
}

function build_debos_rootfs_host {
    cd $BUILDCONF_DIR
    make -f debos_rootfs_host.mk build
}

function build_modules {
	cd  $SCRIPT_DIR/../../External_modules
#	make clean
	make
#	cd $SCRIPT_DIR/../../suplementary-binaries
#	make clean
#	make
}

function transfer_binaries {
# No U-Boot goes to debian-image-recipes: the host disk carries no bootloader,
# the firmware is flashed to the SPI NOR from opencca-flash/flash/snapshot.
rsync -av $SCRIPT_DIR/../../snapshot/lkvm $SCRIPT_DIR/../../debian-image-recipes/overlays/CAEC/.
# QEMU is optional: a tree that has never run build_all.sh qemu has no binaries.
for bin in qemu-system-aarch64 ivshmem-server; do
    if [ -e $SCRIPT_DIR/../../snapshot/$bin ]; then
        rsync -av $SCRIPT_DIR/../../snapshot/$bin $SCRIPT_DIR/../../debian-image-recipes/overlays/CAEC/.
    else
        log "snapshot/$bin missing - run: build_all.sh qemu"
    fi
done
rsync -av $SCRIPT_DIR/../../snapshot/* $SCRIPT_DIR/../../opencca-flash/flash/snapshot/.
}

function run_builds() {
    build_order=("$@")

    echo "Setting build_order: ${build_order[*]}"
    for key in "${build_order[@]}"; do
        build_status["$key"]="not executed"
    done

    for func in "${build_order[@]}"; do
        log "\nBuilding $func...\n"
        # tee's status hides the build's, and the build runs in a subshell
        # (set -e does not reach it): take the build's own exit status.
        if $func 2>&1 | tee -a "$LOG_DIR/$func.log" && [[ ${PIPESTATUS[0]} -eq 0 ]]; then
            build_status["$func"]="Success (see $func.log)"
        else
            build_status["$func"]="Failed (see $func.log)"
            build_failed=1
        fi
    done
}

function print_status() {

    log "\nBuild Summary:\n"
    for key in "${!build_status[@]}"; do
        msg=$(printf "  %-30s: %s\n" "$key" "${build_status[$key]}")
        log "$msg"
    done

    log "\nLog directory: $LOG_DIR"
    log "Full log: $LOG_FILE\n"
    log "Snapshot directory $SNAPSHOT_DIR:\n"

    for entry in $(ls $SNAPSHOT_DIR); do
        msg=$(printf "  %s" "$entry")
        log "$msg"
    done

}



# Main
mkdir -p $LOG_DIR
exec &> >(tee -a "$LOG_FILE")
log "Date: $(date +%Y-%m-%d_%H-%M-%S):"
echo "Executing command: ${1-} ..."

# set -x
build_seq=
case "${1-}" in
    all) build_seq=${build_all[@]} ;;
    firmware) build_seq=${build_firmware[@]} ;;
    kvmtool) build_seq=${build_kvmtool[@]} ;;
    qemu) build_seq=${build_qemu[@]} ;;
    openshell) build_seq=${build_openshell[@]} ;;
    linux) build_seq=${build_linux[@]} ;;
    linux_guest) build_seq=${build_linux_guest[@]} ;;
    modules) build_seq=${build_modules[@]} ;;
    help) echo "$0 [all|firmware|kvmtool|qemu|openshell|linux|linux_guest|modules|help]"; exit ;;
    *) build_seq=${build_all[@]} ;;
esac

build_failed=0
time run_builds ${build_seq[@]}
if [[ $build_failed -eq 0 ]]; then
    transfer_binaries
else
    # Leave opencca-flash/flash/snapshot as it was: syncing now would hand
    # flash.sh the previous build's firmware next to this build's other
    # outputs, with nothing to tell them apart.
    log "\nA build failed: snapshot/ NOT synced to opencca-flash/flash/snapshot/ - fix the build and rerun.\n"
fi
print_status
exit $build_failed
