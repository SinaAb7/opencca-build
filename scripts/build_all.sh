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
ENV_FILE=$SCRIPT_DIR/../buildconf/env.mk

# Get environment from makefile
eval "$(make -f $ENV_FILE print-vars | sed 's/^/export /')" &>/dev/null || true

# Colors
COLOR="\e[35m"
RESET="\e[0m"

# Paths
BUILDCONF_DIR=$OPENCCA_BUILD_DIR/buildconf
LOG_DIR="$SCRIPT_DIR/build_log"
LOG_FILE="$LOG_DIR/stdout.log"

build_quick_start=(
    build_kvmtool
    build_linux
    build_firmware
)

build_all=(
    build_kvmtool
    build_linux
    build_firmware
    build_debos_rootfs_host
)

declare -A build_status

trap 'echo "Error on line $LINENO with exit code $?" && exit 1' ERR SIGINT

function log() { echo -e "${COLOR}$1${RESET}"; }

# Build Functions:
function build_kvmtool {
    cd $BUILDCONF_DIR
    make -f kvmtool.mk build
}

function build_linux {
    cd $BUILDCONF_DIR
    ./linux.mk kernel && \
    ./linux.mk DEBIAN_RELEASE_DIR="$SNAPSHOT_DIR/" debian
}

function build_firmware {
    cd $BUILDCONF_DIR
    make -f firmware_opencca.mk build
}

function build_debos_rootfs_host {
    cd $BUILDCONF_DIR
    make -f debos_rootfs_host.mk build
}

function run_builds() {
    build_order=("$@")

    echo "Setting build_order: ${build_order[*]}"
    for key in "${build_order[@]}"; do
        build_status["$key"]="not executed"
    done

    for func in "${build_order[@]}"; do
        log "\nBuilding $func...\n"
        $func 2>&1 | tee -a "$LOG_DIR/$func.log" \
            && build_status["$func"]="Success (see $func.log)" \
            || { build_status["$func"]="Failed (see $func.log)"; }

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
    quick_start) build_seq=${build_quick_start[@]} ;;
    help) echo "$0 all|quick_start"; exit ;;
    *) build_seq=${build_quick_start[@]} ;;
esac

time run_builds ${build_seq[@]}
print_status
