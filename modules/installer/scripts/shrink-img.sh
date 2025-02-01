#!/usr/bin/env bash

if [ -f "/.dockerenv" ]; then
  in_docker=true
fi

legacy_installer=true
if [ -f "./rootfs.img" ] && [ -f "./bootfs.bin" ]; then
  legacy_installer=false
elif [ ! -d "./linux" ] || [ ! -f "./linux/rootfs.img" ]; then
  echo "this script must be run in the top of the installer directory, not from the scripts dir"
  exit 1
fi

if [ $legacy_installer == false ]; then
  rootfs_path="./rootfs.img"
else
  rootfs_path="./linux/rootfs.img"
fi

mkdir -p /mnt/image
if [ "$in_docker" == true ]; then
  mount -o compress=zstd,noatime,nodatacow,noautodefrag $rootfs_path /mnt/image
else
  losetup /dev/loop0 $rootfs_path
  mount -o compress=zstd,noatime,nodatacow,noautodefrag /dev/loop0 /mnt/image
fi

echo "defragmenting and compressing filesystem - this will take a while"
btrfs property set /mnt/image/root compression zstd
btrfs filesystem defragment -r -czlib /mnt/image/root

min_size=$(btrfs filesystem usage -b /mnt/image | grep "Free (estimated)" | awk -F'min: ' '{print $2}' | awk '{gsub(/[()]/, ""); print $1 - 33554432}')
btrfs filesystem resize "-$min_size" /mnt/image

btrfs filesystem defragment -r -czlib /mnt/image/root

min_size=$(btrfs filesystem usage -b /mnt/image | grep "Free (estimated)" | awk -F'min: ' '{print $2}' | awk '{gsub(/[()]/, ""); print $1 - 33554432}')
btrfs filesystem resize "-$min_size" /mnt/image

btrfs filesystem defragment -r -czlib /mnt/image/root

# shellcheck disable=SC2034
for i in {0..5}; do
  min_size=$(btrfs filesystem usage -b /mnt/image | grep "Free (estimated)" | awk -F'min: ' '{print $2}' | awk '{gsub(/[()]/, ""); print $1 - 1048576}')
  btrfs filesystem resize "-$min_size" /mnt/image
done

umount /mnt/image
if [ "$in_docker" != true ]; then
  losetup -d /dev/loop0
fi

trim_size=$(perl <$rootfs_path -e 'seek(STDIN, 0x10070, 0) or sysread(STDIN, $_, 0x10070) == 0x10070 or die "seek"; sysread(STDIN, $_, 8) == 8 or die "read"; print unpack("Q<", $_), "\n"')
truncate -s "$trim_size" $rootfs_path
