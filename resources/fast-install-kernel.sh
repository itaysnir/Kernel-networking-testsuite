#!/bin/bash
# intended to run from kernel source directory

set -xeuo pipefail

KERNEL_SRC="$1"
RELEASE="$2"

cd "$KERNEL_SRC"
mkdir -p /tmp/boot
mount -t tmpfs tmpfs /tmp/boot
installkernel "$RELEASE" arch/x86/boot/bzImage System.map /tmp/boot

# do not always regenerate the initramfs, it's a painfully slow process and
# we don't need to update it for kernel updates, and for module updates
# we already installed the latest versions in /lib/modules, so usually they will
# be loaded from latest state and if not we can force load them from there at runtime.
if [[ ! -f "/boot/initrd.img-$RELEASE" ]]; then
    echo "generating initramfs image for the first time..."

    # we generate an initramfs in a tmpfs since the /boot partition might
    # be too-small for the process to complete. it should also be faster this way.
    update-initramfs -b /tmp/boot -u -k "$RELEASE"
fi

rsync -av /tmp/boot/ /boot/
linux-update-symlinks install "$RELEASE" "/boot/vmlinuz-$RELEASE"
update-grub
umount /tmp/boot
sync
