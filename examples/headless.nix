{ modulesPath, ... }:
{
  imports = [ "${modulesPath}/profiles/minimal.nix" ];
  superbird.gui.enable = false;

  superbird.stateVersion = "0.2";
  system.stateVersion = "24.11";
}
