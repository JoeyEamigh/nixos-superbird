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

  fileSystems = {
    "/" = lib.mkForce {
      inherit device;
      fsType = "ext4";
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
