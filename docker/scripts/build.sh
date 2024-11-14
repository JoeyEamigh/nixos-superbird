#!/usr/bin/env bash
set -eo pipefail
# set -x

if [ -z "${SUPERBIRD_CHOWN}" ]; then
  SUPERBIRD_CHOWN="1000:1000"
fi

echo "building installer..."
nix build '.#nixosConfigurations.superbird.config.system.build.installer' -j"$(nproc)" --show-trace
echo "kernel is $(stat -Lc%s -- result/linux/kernel | numfmt --to=iec)"
echo "initrd is $(stat -Lc%s -- result/linux/initrd.img | numfmt --to=iec)"
echo "rootfs (sparse) is $(stat -Lc%s -- result/linux/rootfs.img | numfmt --to=iec)"

rm -rf ./out
mkdir /root/out
cp -r ./result/* /root/out/
cd /root/out

echo "shrinking rootfs image..."
./scripts/shrink-img.sh
echo "rootfs (compact) is $(stat -Lc%s -- ./linux/rootfs.img | numfmt --to=iec)"

mv /root/out /workdir/out
chown -R "$SUPERBIRD_CHOWN" /workdir/out

echo "done! find your installer at ./out!"
