#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# --------------------------------
# Build components
# --------------------------------

# Checkout build_all.sh to see how the components are built.

/opencca/opencca-build/scripts/build_all.sh quick_start
# /opencca/opencca-build/scripts/build_all.sh all


#
# Also download pre-built rootfs
#