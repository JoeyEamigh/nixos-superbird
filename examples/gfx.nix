{ pkgs, ... }:
{
  superbird.gui.app = "${pkgs.mesa-demos}/bin/glxgears";

  superbird.stateVersion = "0.2";
  system.stateVersion = "24.11";
}
