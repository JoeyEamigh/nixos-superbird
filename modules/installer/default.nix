{ pkgs, config, ... }:
{
  system.build.installer = pkgs.stdenv.mkDerivation {
    name = "installer";

    buildCommand = ''
      set -x

      mkdir $out
      cp ${./install/install.sh} $out/install.sh
      cp ${./install/install.py} $out/install.py
      cp ${./install/superbird_device.py} $out/superbird_device.py
      cp ${./install/readme.md} $out/readme.md

      cp -r ${./install/boot} $out/boot
      cp -r ${./install/env} $out/env
      cp -r ${./install/scripts} $out/scripts

      mkdir $out/ssh
      cp ${../net/ssh/ssh_host_ed25519_key} $out/ssh/ssh_ed25519_key
      cp ${../net/ssh/ssh_host_rsa_key} $out/ssh/ssh_rsa_key

      mkdir $out/linux
      cp ${../fs/resources/meson-g12a-superbird.dtb} $out/linux/meson-g12a-superbird.dtb
      cp ${config.system.build.initrd}/initrd.img $out/linux/initrd.img
      cp ${config.system.build.toplevel}/kernel $out/linux/kernel
      cp ${config.system.build.btrfs} $out/linux/rootfs.img
    '';
  };
}
