{ modulesPath, ... }:
{
  imports = [ "${modulesPath}/profiles/minimal.nix" ];

  superbird.gui.enable = false;
  system.stateVersion = "24.11";
}
