{
  config,
  pkgs,
  ...
}:
# let
# installBootLoader = pkgs.writeScript "install-bootloader.sh" ''
#   mkdir -p /mnt/boot
#   mount ${device} /mnt/boot

#   cp ${../resources/bootargs.txt} /mnt/boot/bootargs.txt
#   cp ${config.system.build.toplevel}/kernel /mnt/boot/kernel
#   cp ${config.system.build.toplevel}/dtbs/superbird.dtb /mnt/boot/superbird.dtb

#   umount /mnt/boot
# '';
#
# in
{
  imports = [
    ./env.nix
    ./logo.nix
  ];

  # system.build.installBootLoader = installBootLoader;

  system.build.blankBootfs = pkgs.stdenv.mkDerivation {
    name = "bootfs-blank.bin";

    nativeBuildInputs = with pkgs; [ unzip ];

    dontUnpack = true;
    buildPhase =
      let
        env = config.system.build.bootenv;
        logos = config.system.build.bootlogos;
      in
      ''
        unzip ${./resources/bootfs-blank.bin.zip}

        # load env partition
        # dd if=${env} of=bootfs-blank.bin bs=1M seek=116 conv=notrunc

        # load bootlogo partition
        dd if=${logos} of=bootfs-blank.bin bs=1M seek=156 conv=notrunc
      '';

    installPhase = "mv bootfs-blank.bin $out";
  };
}
