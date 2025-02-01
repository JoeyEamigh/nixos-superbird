{ ... }:
{
  imports = [
    ./kernel
    ./firmware
    ./drivers
    ./init.nix
    ./hardware.nix
    ./gpio.nix
  ];
}
