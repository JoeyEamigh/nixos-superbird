{
  config,
  lib,
  modulesPath,
  ...
}:
let
  cfg = config.superbird;
in
{
  imports = [
    ./users.nix
    ./misc.nix
    ./lack-of-security.nix
    # ./bridgething.nix

    # "${modulesPath}/profiles/perlless.nix"
    # "${modulesPath}/profiles/headless.nix"
    "${modulesPath}/profiles/minimal.nix"
  ];

  disabledModules = [
    "${modulesPath}/profiles/all-hardware.nix"
    "${modulesPath}/profiles/base.nix"
  ];

  nix = {
    enable = cfg.packages.nix;

    settings = lib.mkIf cfg.packages.nix {
      experimental-features = "nix-command flakes";
      auto-optimise-store = true;
      trusted-users = [
        "root"
        "@wheel"
      ];
    };

    optimise.automatic = lib.mkIf cfg.packages.nix true;
    optimise.dates = lib.mkIf cfg.packages.nix [ "03:45" ];

    gc = lib.mkIf cfg.packages.nix {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 1d";
    };

    extraOptions = lib.mkIf cfg.packages.nix ''
      min-free = ${toString (100 * 1024 * 1024)}
      max-free = ${toString (2 * 1024 * 1024 * 1024)}
    '';
  };
}
