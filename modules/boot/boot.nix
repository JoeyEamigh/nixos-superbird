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
  system.activationScripts.installInitScript = ''
    ln -fs $systemConfig/${if cfg.legacy-installer.enable then "prepare-root" else "init"} /bin/init
  '';

  system.build.initialRamdisk = "";
  system.build.initialRamdiskSecretAppender = "";

  hardware.enableRedistributableFirmware = lib.mkForce false;
  boot = {
    loader.grub.enable = false;

    initrd.enable = lib.mkForce cfg.legacy-installer.enable;
    initrd.includeDefaultModules = lib.mkForce false;
    initrd.supportedFilesystems = lib.mkForce [ ];
    initrd.kernelModules = lib.mkForce [ ];
    supportedFilesystems = lib.mkForce [
      "vfat"
      "ext4"
    ];

    postBootCommands = ''
      set -x
      # On the first boot do some maintenance tasks
      if [ -f /nix-path-registration ]; then
        echo "boot >>> running first boot setup" > /dev/kmsg

        # Ensure that / and a few others are owned by root https://github.com/NixOS/nixpkgs/pull/320643
        # echo "boot >>> chowning root" > /dev/kmsg
        # chown -f 0:0 /
        # chown -f 0:0 /nix
        # chown -f 0:0 /bin

        # expand filesystem
        echo "boot >>> expanding the root filesystem" > /dev/kmsg

        # Figure out device names for the boot device and root filesystem.
        rootPart=$(${pkgs.util-linux}/bin/findmnt -n -o SOURCE /)
        bootDevice=$(lsblk -npo PKNAME $rootPart)
        partNum=$(lsblk -npo MAJ:MIN $rootPart | ${pkgs.gawk}/bin/awk -F: '{print $2}')

        # Resize the root partition and the filesystem to fit the disk
        echo ",+," | sfdisk -N$partNum --no-reread $bootDevice
        ${pkgs.parted}/bin/partprobe
        ${pkgs.e2fsprogs}/bin/resize2fs $rootPart

        # echo "boot >>> unsetting root password" > /dev/kmsg
        # passwd -d root

        echo "boot >>> creating swap directory" > /dev/kmsg
        mkdir -p /swap

        # Register the contents of the initial Nix store
        echo "boot >>> registering initial nix store" > /dev/kmsg
        ${config.nix.package.out}/bin/nix-store --load-db < /nix-path-registration

        # nixos-rebuild also requires a "system" profile and an /etc/NIXOS tag.
        touch /etc/NIXOS
        # ${config.nix.package.out}/bin/nix-env -p /nix/var/nix/profiles/system --set /run/current-system

        # Prevents this from running on later boots.
        rm -f /nix-path-registration

        echo "boot >>> done!" > /dev/kmsg
      fi
    '';
  };
}
