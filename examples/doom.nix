{ pkgs, ... }:
let
  doomDotWad = pkgs.fetchurl {
    url = "https://archive.org/download/theultimatedoom_doom2_doom.wad/DOOM.WAD%20%28For%20GZDoom%29/DOOM.WAD";
    hash = "sha256-b982GEe0YijP69nzrwnNhEKCrHXz7bthykyycQPOLn8=";
  };
in
{
  superbird.gui.app = "${pkgs.doomretro}/bin/doomretro -iwad ${doomDotWad}";
  system.stateVersion = "24.11";
}
