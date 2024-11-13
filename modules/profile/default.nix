{
  config,
  pkgs,
  modulesPath,
  lib,
  ...
}:
let
  cfg = config.superbird;
in
{
  imports = [
    ./users.nix

    # "${modulesPath}/profiles/headless.nix"
    "${modulesPath}/profiles/minimal.nix"
  ];

  disabledModules = [
    "${modulesPath}/profiles/all-hardware.nix"
    "${modulesPath}/profiles/base.nix"
  ];

  environment.systemPackages = lib.mkIf cfg.packages.useful [
    # useful
    pkgs.btop
    pkgs.neovim

    # fun
    pkgs.neofetch
  ];

  nix = {
    settings = {
      experimental-features = "nix-command flakes";
      auto-optimise-store = true;
      trusted-users = [
        "root"
        "@wheel"
      ];
    };

    optimise.automatic = true;
    optimise.dates = [ "03:45" ];

    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 1d";
    };

    extraOptions = ''
      min-free = ${toString (100 * 1024 * 1024)}
      max-free = ${toString (2 * 1024 * 1024 * 1024)}
    '';
  };
}
