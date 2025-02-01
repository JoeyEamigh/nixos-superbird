build config="chrome-example":
  nix build '.#nixosConfigurations.{{config}}.config.system.build.toplevel' -j$(nproc) --show-trace

fs config="chrome-example":
  nix build '.#nixosConfigurations.{{config}}.config.system.build.btrfs' -j$(nproc) --show-trace
  echo "rootfs is $(stat -Lc%s -- result | numfmt --to=iec)"

installer config="chrome-example":
  #!/usr/bin/env bash
  set -euo pipefail

  nix build '.#nixosConfigurations.{{config}}.config.system.build.installer' -j$(nproc) --show-trace
  echo "kernel is $(stat -Lc%s -- result/builder/kernel | numfmt --to=iec)"
  echo "rootfs is $(stat -Lc%s -- result/rootfs.img | numfmt --to=iec)"

  sudo rm -rf ./out
  mkdir ./out
  cp -r ./result/* ./out/
  chown -R $(whoami):$(whoami) ./out
  cd ./out

  sudo ./scripts/make-bootfs.sh
  echo "bootfs built!"

  just zip-installer


run-installer config="chrome-example":
  just installer {{config}}
  cd out && ./install.sh

zip-installer:
  #!/usr/bin/env bash
  set -euo pipefail

  cd ./out/
  zip nixos.zip rootfs.img bootfs.bin meta.json env.txt readme.md

cache:
  nix run nixpkgs#attic-client -- push superbird \
    $(nix build .#nixosConfigurations.chrome-example.config.system.build.toplevel --no-link --print-out-paths) \
    $(nix build .#nixosConfigurations.headless-example.config.system.build.toplevel --no-link --print-out-paths)

ssh:
  ssh -i ./modules/net/ssh/ssh_host_ed25519_key root@172.16.42.2

docker:
  # cd docker && docker buildx build -f ./Dockerfile.nix --platform linux/amd64,linux/arm64 -t ghcr.io/joeyeamigh/nixos-superbird/builder:latest --push .
  cd docker && docker buildx build -f ./Dockerfile.nix --platform linux/amd64 -t ghcr.io/joeyeamigh/nixos-superbird/builder:latest .

run-docker-example:
  docker run --privileged --rm -it -v ./examples/flake/:/workdir ghcr.io/joeyeamigh/nixos-superbird/builder:latest

inspect-image config="chrome-example":
  #!/usr/bin/env bash
  set -euo pipefail

  just fs {{config}}

  sudo mkdir -p /mnt/image
  sudo losetup /dev/loop0 ./result
  sudo mount /dev/loop0 /mnt/image

  echo "filesystem mounted at /mnt/image"
  read -p "press enter when done to unmount"

  sudo umount /mnt/image
  sudo losetup -d /dev/loop0
