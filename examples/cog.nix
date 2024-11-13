{ pkgs, ... }:
{
  superbird.gui.app = "${pkgs.cog}/bin/cog https://github.com/JoeyEamigh/nixos-superbird";
  system.stateVersion = "24.11";
}
