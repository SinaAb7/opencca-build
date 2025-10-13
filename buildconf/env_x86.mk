include $(CURDIR)/../buildconf/env.mk
CCACHE        := ccache

# Prefix of the GNU cross-compiler you installed (see notes below)
export CROSS_COMPILE=/usr/bin/aarch64-linux-gnu-

# Target architecture seen by the kernel/Kbuild world
export ARCH=arm64
export CC=${CROSS_COMPILE}gcc
#export AS=${CROSS_COMPILE}as
export LD=${CROSS_COMPILE}ld

# Kernel makefiles honour V=1 for verbose; keep it plumbed through.
MAKEFLAGS    += V=$(V)
