{
  config,
  pkgs,
  ...
}:
let
  cfg = config.superbird;
  inherit (pkgs) stdenv;
in
{
  system.build.installer = stdenv.mkDerivation {
    name = "terbium";

    buildCommand =
      let
        meta = pkgs.replaceVars ./meta.json {
          inherit (cfg) name version description;
        };
      in
      ''
        set -x

        mkdir $out
        cp ${meta} $out/meta.json
        cp ${./readme.md} $out/readme.md
        cp -r ${../scripts} $out/scripts

        mkdir $out/ssh
        cp ${../../net/ssh/ssh_host_ed25519_key} $out/ssh/ssh_ed25519_key
        cp ${../../net/ssh/ssh_host_rsa_key} $out/ssh/ssh_rsa_key

        mkdir $out/builder
        cp ${../../boot/bootfs/resources/bootargs.txt} $out/builder/bootargs.txt
        cp ${config.system.build.blankBootfs} $out/builder/bootfs-blank.bin
        cp ${config.system.build.toplevel}/kernel $out/builder/kernel
        cp ${config.system.build.toplevel}/dtbs/superbird.dtb $out/builder/superbird.dtb
        cp ${config.system.build.initrd}/initrd.img $out/builder/initrd

        cp ${config.system.build.bootenvtxt} $out/env.txt
        cp ${config.system.build.ext4} $out/rootfs.img

        ${
          if cfg.installer.manualScript then
            ''
              cp -r ${../boot} $out/boot
              cp -r ${./manual} $out/manual
            ''
          else
            ''''
        }
      '';
  };
}
