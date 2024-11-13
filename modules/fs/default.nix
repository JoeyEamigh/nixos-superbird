{ config, lib, ... }:
let
  cfg = config.superbird;

  device = if cfg.qemu then "/dev/vda2" else "/dev/mmcblk2p2";
in
{
  imports = [
    ./btrfs.nix
    ./initrd.nix
    ./boot.nix
  ];

  fileSystems = {
    "/" = lib.mkForce {
      inherit device;
      fsType = "btrfs";
      options = [
        "subvol=root"
        "compress=zstd"
        "noatime"
      ];
    };
    "/var/log" = {
      inherit device;
      fsType = "btrfs";
      options = [
        "subvol=log"
        "compress=zstd"
        "noatime"
      ];
    };
    "/swap" = lib.mkIf cfg.swap.enable {
      inherit device;
      fsType = "btrfs";
      options = [
        "subvol=swap"
        "noatime"
      ];
    };
  };

  swapDevices = lib.mkIf cfg.swap.enable [
    {
      device = "/swap/swapfile";
      size = cfg.swap.size;
    }
  ];

}
