{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.superbird;
in
{
  config = lib.mkIf cfg.legacy-installer.enable {
    system.build.installer = pkgs.stdenv.mkDerivation {
      name = "installer";

      buildCommand = ''
        set -x

        mkdir $out
        cp ${./install.sh} $out/install.sh
        cp ${./install.py} $out/install.py
        cp ${./superbird_device.py} $out/superbird_device.py
        cp ${./readme.md} $out/readme.md

        cp -r ${./boot} $out/boot
        cp -r ${./env} $out/env
        cp -r ${../scripts} $out/scripts

        mkdir $out/ssh
        cp ${../../net/ssh/ssh_host_ed25519_key} $out/ssh/ssh_ed25519_key
        cp ${../../net/ssh/ssh_host_rsa_key} $out/ssh/ssh_rsa_key

        mkdir $out/linux
        cp ${config.system.build.initrd}/initrd.img $out/linux/initrd.img
        cp ${config.system.build.toplevel}/kernel $out/linux/kernel
        cp ${config.system.build.toplevel}/dtbs/superbird.dtb $out/linux/meson-g12a-superbird.dtb
        cp ${config.system.build.ext4} $out/linux/rootfs.img
      '';
    };
  };
}
