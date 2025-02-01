{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.superbird;

  mali = pkgs.callPackage ./gfx/mali.nix { };
  appleMfi = pkgs.callPackage ./mfi/apple-mfi.nix { };
in
{
  boot.kernelPackages = pkgs.recurseIntoAttrs (pkgs.linuxPackagesFor pkgs.superbirdKernel);
  boot.extraModulePackages = lib.mkIf cfg.gpu.enable [
    mali
    appleMfi
  ];
  boot.kernelModules = lib.mkIf cfg.gpu.enable [
    "mali_kbase"
    "appleMfi"
  ];
}
