build config="cog-example":
  nix build '.#nixosConfigurations.{{config}}.config.system.build.toplevel' -j$(nproc) --show-trace

initrd config="cog-example":
  nix build '.#nixosConfigurations.{{config}}.config.system.build.initrd' -j$(nproc) --show-trace
  echo "initrd is $(stat -Lc%s -- result/initrd | numfmt --to=iec)"

fs config="cog-example":
  nix build '.#nixosConfigurations.{{config}}.config.system.build.btrfs' -j$(nproc) --show-trace
  echo "rootfs is $(stat -Lc%s -- result | numfmt --to=iec)"

installer config="cog-example":
  #!/usr/bin/env bash
  set -euo pipefail

  nix build '.#nixosConfigurations.{{config}}.config.system.build.installer' -j$(nproc) --show-trace
  echo "kernel is $(stat -Lc%s -- result/linux/kernel | numfmt --to=iec)"
  echo "initrd is $(stat -Lc%s -- result/linux/initrd.img | numfmt --to=iec)"
  echo "rootfs (sparse) is $(stat -Lc%s -- result/linux/rootfs.img | numfmt --to=iec)"

  sudo rm -rf ./out
  mkdir ./out
  cp -r ./result/* ./out/
  chown -R $(whoami):$(whoami) ./out
  cd ./out

  sudo ./scripts/shrink-img.sh
  echo "rootfs (compact) is $(stat -Lc%s -- ./linux/rootfs.img | numfmt --to=iec)"


run-installer config="cog-example":
  just installer {{config}}
  cd out && ./install.sh

zip-installer:
  #!/usr/bin/env bash
  set -euo pipefail

  cd ./out/
  zip -r nixos-superbird-installer.zip .

cache:
  attic push superbird \
    $(nix build .#nixosConfigurations.cog-example.config.system.build.toplevel --no-link --print-out-paths) \
    $(nix build .#nixosConfigurations.headless-example.config.system.build.toplevel --no-link --print-out-paths) \
    $(nix build .#nixosConfigurations.qemu-example.config.system.build.toplevel --no-link --print-out-paths)

ssh:
  ssh -i ./modules/net/ssh/ssh_host_ed25519_key root@172.16.42.2

docker:
  cd docker && docker buildx build -f ./Dockerfile.nix --platform linux/amd64,linux/arm64 -t ghcr.io/joeyeamigh/nixos-superbird/builder:latest --push .
  # cd docker && docker buildx build -f ./Dockerfile.nix --platform linux/amd64 -t ghcr.io/joeyeamigh/nixos-superbird/builder:latest .

run-docker-example:
  docker run --privileged --rm -it -v ./examples/flake/:/workdir ghcr.io/joeyeamigh/nixos-superbird/builder:latest

inspect-image config="cog-example":
  #!/usr/bin/env bash
  set -euo pipefail

  just fs {{config}}

  sudo losetup /dev/loop69 ./result
  sudo mkdir -p /mnt/image
  sudo mount -o compress=zstd,noatime /dev/loop69 /mnt/image

  echo "filesystem mounted at /mnt/image"
  read -p "press enter when done to unmount"

  sudo umount /mnt/image
  sudo losetup -d /dev/loop69

build-qemu:
  nix build '.#nixosConfigurations.qemu-example.config.system.build.toplevel' -j$(nproc) --show-trace

build-qemu-fs:
  nix build '.#nixosConfigurations.qemu-example.config.system.build.toplevel' -j$(nproc) --show-trace
  echo "qemu rootfs is $(stat -Lc%s -- result | numfmt --to=iec)"

build-qemu-init:
  nix build '.#nixosConfigurations.qemu-example.config.system.build.initfs' -j$(nproc) --show-trace
  echo "qemu initrd is $(stat -Lc%s -- result/initrd | numfmt --to=iec)"
