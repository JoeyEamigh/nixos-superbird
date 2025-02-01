{
  stdenv,
  lib,
}:
stdenv.mkDerivation {
  pname = "appleMfi";
  version = "1-spotify";

  dontConfigure = true;
  dontBuild = true;

  src = ./resources;

  installPhase = ''
    mkdir $out
    cp $src/* $out
  '';

  meta = {
    description = "Spotify's Apple MFi Auth kernel drivers";
    platforms = lib.platforms.linux;
  };
}
