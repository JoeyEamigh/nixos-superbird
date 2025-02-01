{
  config,
  pkgs,
  lib,
  ...
}:
{
  system.activationScripts.installInitScript = ''
    ln -fs $systemConfig/init /bin/init
  '';

  hardware.enableRedistributableFirmware = lib.mkForce false;
  boot = {
    loader.grub.enable = false;

    initrd = {
      enable = true;
      compressor = "gzip";

      includeDefaultModules = lib.mkForce false;
      supportedFilesystems = lib.mkForce [ ];
      availableKernelModules = lib.mkForce [ ];
      kernelModules = lib.mkForce [ ];
    };

    postBootCommands = ''
      set -x
      # On the first boot do some maintenance tasks
      if [ -f /firstboot ]; then
        echo "boot >>> running first boot setup" > /dev/kmsg

        if [ ! -f /nix-path-registration ]; then
          echo "boot >>> detected squashfs - copying path registration information" > /dev/kmsg
          cp /nix/.ro-store/nix-path-registration /nix-path-registration
        fi

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
        ${config.nix.package.out}/bin/nix-env -p /nix/var/nix/profiles/system --set /run/current-system

        # Prevents this from running on later boots.
        rm -f /nix-path-registration
        rm -f /firstboot

        echo "boot >>> done!" > /dev/kmsg
      fi
    '';
  };

  system.build.initrd = pkgs.makeInitrd {
    compressor = "gzip";
    makeUInitrd = true;
    prepend = [ "${config.system.build.initialRamdisk}/initrd" ];

    # this is just here so that nix will build an empty uboot initrd
    contents = [
      {
        object = pkgs.makeModulesClosure {
          rootModules = [ ];
          kernel = config.system.modulesTree;
          firmware = [ ];
          allowMissing = true;
        };
        symlink = "/lib";
      }
    ];
  };
}
