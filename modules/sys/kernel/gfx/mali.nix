{
  stdenv,
  lib,
}:
stdenv.mkDerivation {
  pname = "mali";
  version = "1-spotify";

  dontConfigure = true;
  dontBuild = true;

  src = ./resources;

  installPhase = ''
    mkdir $out
    cp $src/* $out
  '';

  meta = {
    description = "Spotify's Mali kernel driver";
    platforms = lib.platforms.linux;
  };
}
