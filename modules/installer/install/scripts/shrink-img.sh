#!/bin/bash

if [ ! -d "./linux" ] || [ ! -f "./linux/rootfs.img" ]; then
  echo "this script must be run in the top of the installer directory, not from the scripts dir"
  exit 1
fi

losetup /dev/loop69 ./linux/rootfs.img
mkdir -p /mnt/image
mount -o compress=zstd,noatime /dev/loop69 /mnt/image
btrfs subvolume set-default 256 /mnt/image

echo "defragmenting and compressing filesystem - this will take a while"
btrfs property set /mnt/image/root compression zstd
btrfs filesystem defragment -r -czlib /mnt/image/root

min_size=$(btrfs filesystem usage -b /mnt/image | grep "Free (estimated)" | awk -F'min: ' '{print $2}' | awk '{gsub(/[()]/, ""); print $1 - 33554432}')
btrfs filesystem resize "-$min_size" /mnt/image

# shellcheck disable=SC2034
for i in {0..5}; do
  min_size=$(btrfs filesystem usage -b /mnt/image | grep "Free (estimated)" | awk -F'min: ' '{print $2}' | awk '{gsub(/[()]/, ""); print $1 - 1048576}')
  btrfs filesystem resize "-$min_size" /mnt/image
done

umount /mnt/image
losetup -d /dev/loop69

trim_size=$(perl <./linux/rootfs.img -e 'seek(STDIN, 0x10070, 0) or sysread(STDIN, $_, 0x10070) == 0x10070 or die "seek"; sysread(STDIN, $_, 8) == 8 or die "read"; print unpack("Q<", $_), "\n"')
truncate -s "$trim_size" ./linux/rootfs.img
