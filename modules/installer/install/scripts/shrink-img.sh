#!/usr/bin/env bash

if [ -f "/.dockerenv" ]; then
  in_docker=true
fi

if [ ! -d "./linux" ] || [ ! -f "./linux/rootfs.img" ]; then
  echo "this script must be run in the top of the installer directory, not from the scripts dir"
  exit 1
fi

mkdir -p /mnt/image
if [ "$in_docker" == true ]; then
  mount -o compress=zstd,noatime ./linux/rootfs.img /mnt/image
else
  losetup /dev/loop0 ./linux/rootfs.img
  mount -o compress=zstd,noatime /dev/loop0 /mnt/image
fi

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
if [ "$in_docker" != true ]; then
  losetup -d /dev/loop0
fi

trim_size=$(perl <./linux/rootfs.img -e 'seek(STDIN, 0x10070, 0) or sysread(STDIN, $_, 0x10070) == 0x10070 or die "seek"; sysread(STDIN, $_, 8) == 8 or die "read"; print unpack("Q<", $_), "\n"')
truncate -s "$trim_size" ./linux/rootfs.img
