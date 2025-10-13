#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
ROOT_DIR=$SCRIPT_DIR/../../

USER=user
#HOST=192.33.93.163


# Sample entry
# label image
#     menu label CCA Kernel Debian GNU/Linux trixie/sid 6.12.0-opencca-wip
#     linux /boot/Image
#     initrd /boot/initrd.img-6.12.0-opencca-wip
#     fdtdir /usr/lib/linux-image-6.12.0-opencca-wip/    
#     append root=UUID=3f9404cc-5cb5-46c4-90f5-3008a65fedd1 rootwait maxcpus=2  maxcpus=2 isolcpus=1 nohlt cpuidle.off=1 rcupdate.rcu_cpu_st


# scp -r $SNAPSHOT_DIR/Image user@192.33.93.108:/tmp/Image && \
# ssh user@192.33.93.108 "sudo cp -rf /tmp/Image /boot/Image && ls -al /boot | grep Image"


set -x
ssh $USER@$HOST "sudo cp -rf /mnt/snapshot/Image /boot/Image"
ssh $USER@$HOST "ls -al /boot"

ssh $USER@$HOST "sudo cat /boot/extlinux/extlinux.conf"

