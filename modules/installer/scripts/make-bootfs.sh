#!/usr/bin/env bash
set -oe pipefail

if [ -f "/.dockerenv" ]; then
  in_docker=true
fi

if [ ! -d "./builder" ] || [ ! -f "./builder/bootfs-blank.bin" ]; then
  echo "this script must be run in the top of the installer directory, not from the scripts dir"
  exit 1
fi

mv ./builder/bootfs-blank.bin bootfs.bin

mkdir -p /mnt/image
if [ "$in_docker" == true ]; then
  mount -o loop,offset=4194304,size=33554432 -t vfat /dev/loop0 /mnt/image
else
  losetup --offset 4194304 --size 33554432 /dev/loop0 ./bootfs.bin
  mount -t vfat /dev/loop0 /mnt/image
fi

cp ./builder/kernel /mnt/image/Image
cp ./builder/superbird.dtb /mnt/image/superbird.dtb
cp ./builder/bootargs.txt /mnt/image/bootargs.txt

umount /mnt/image
if [ "$in_docker" != true ]; then
  losetup -d /dev/loop0
fi

rm -rf ./builder
