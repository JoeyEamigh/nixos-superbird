{ pkgs, lib, ... }:
{
  options = {
    drivers.libMali = lib.mkOption {
      type = lib.types.package;
    };
  };

  config = {
    drivers.libMali = pkgs.callPackage ./libmali.nix { };
  };
}
