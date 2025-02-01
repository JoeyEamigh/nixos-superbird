{ config, lib, ... }:
let
  cfg = config.superbird;
  device = "/dev/mmcblk0p2";
in
{
  imports = [
    ./bootfs
    ./rootfs
    ./boot.nix
  ];

  fileSystems =
    if cfg.system.squashfs then
      {
        "/" = lib.mkForce {
          inherit device;
          fsType = "ext4";

          neededForBoot = true;
          noCheck = true; # this may be a very bad idea :)
        };

        "/nix/.ro-store" = lib.mkForce {
          fsType = "squashfs";
          device = "/sysroot/nix-store.squashfs";
          options = [
            "loop"
          ] ++ lib.optional (config.boot.kernelPackages.kernel.kernelAtLeast "6.2") "threads=multi";
          neededForBoot = true;
        };

        "/nix/store" = lib.mkForce {
          fsType = "overlay";
          device = "overlay";
          options = [
            "lowerdir=/nix/.ro-store"
            "upperdir=/nix/.rw-store/store"
            "workdir=/nix/.rw-store/work"
          ];
          depends = [
            "/nix/.ro-store"
            "/nix/.rw-store/store"
            "/nix/.rw-store/work"
          ];
          neededForBoot = true;
        };
      }
    else
      {
        "/" = lib.mkForce {
          inherit device;
          fsType = "ext4";
          neededForBoot = true;
        };
      };

  zramSwap = {
    enable = true;
    algorithm = "lzo";
    memoryPercent = 80;
  };

  swapDevices = lib.mkIf cfg.swap.enable [
    {
      device = "/swap/swapfile";
      size = cfg.swap.size;
    }
  ];

  boot.kernel.sysctl = {
    "vm.swappiness" = 10;
  };
}
