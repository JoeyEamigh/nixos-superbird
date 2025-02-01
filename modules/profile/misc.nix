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
  environment.systemPackages = lib.mkIf cfg.packages.useful [
    # useful
    pkgs.btop
    pkgs.neovim

    # fun
    pkgs.neofetch
  ];
}
