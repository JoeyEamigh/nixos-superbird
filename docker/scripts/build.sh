#!/usr/bin/env bash
set -eo pipefail
# set -x

if [ -z "${SUPERBIRD_CHOWN}" ]; then
  SUPERBIRD_CHOWN="1000:1000"
fi

if [ -z "${LEGACY_BUILDER}" ]; then
  LEGACY_BUILDER=false
fi

kernel_path="builder/kernel"
rootfs_path="rootfs.img"

if [ "$LEGACY_BUILDER" == true ]; then
  kernel_path="linux/kernel"
  rootfs_path="linux/rootfs.img"
fi

echo "building installer..."
nix build '.#nixosConfigurations.superbird.config.system.build.installer' -j"$(nproc)" --show-trace
echo "kernel is $(stat -Lc%s -- result/$kernel_path | numfmt --to=iec)"
echo "rootfs is $(stat -Lc%s -- result/$rootfs_path | numfmt --to=iec)"

rm -rf ./out
mkdir /root/out
cp -r ./result/* /root/out/
cd /root/out

if [ "$LEGACY_BUILDER" != true ]; then
  echo "building bootfs..."
  ./scripts/make-bootfs.sh
fi

mv /root/out /workdir/out
chown -R "$SUPERBIRD_CHOWN" /workdir/out

if [ "$LEGACY_BUILDER" != true ]; then
  echo "zipping installer..."
  zip nixos.zip rootfs.img bootfs.bin meta.json env.txt readme.md
fi

echo "done! find your installer at ./out!"
