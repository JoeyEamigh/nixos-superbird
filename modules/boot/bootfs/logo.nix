{ config, pkgs, ... }:
let
  cfg = config.superbird;

  aml-imgpack = pkgs.stdenv.mkDerivation {
    name = "aml-imgpack.py";

    src = pkgs.fetchFromGitHub {
      owner = "bishopdynamics";
      repo = "aml-imgpack";
      rev = "c68715971ec0dd85485b9bd4006946a182984a92";
      sha256 = "sha256-Eaier7+AgWZEPT9bqSvpo8S0JoUT1/RX0KINUbEpuxo=";
    };

    installPhase = "cp $src/aml-imgpack.py $out";
  };

  bootlogos = pkgs.stdenv.mkDerivation {
    name = "bootlogos.bin";

    nativeBuildInputs = with pkgs; [ imagemagick ];

    src = ./resources/images;

    buildPhase = ''
      mkdir -p converted
      cp $src/*.bmp converted/

      mkdir -p unconverted
      cp $src/*.png unconverted/

      ${
        if cfg.boot.logo != null then
          ''
            rm unconverted/bootup.png
            cp ${cfg.boot.logo} unconverted/bootup.png
          ''
        else
          ''''
      }

      for img in unconverted/*.png; do
        dimensions=$(magick identify -format "%wx%h" "$img")
        width=''${dimensions%x*}
        height=''${dimensions#*x}
        if [ "$width" -gt "$height" ]; then
          magick "$img" -rotate 90 -resize 480x800^ -gravity center -extent 480x800 -define bmp:format=bmp4 -type truecolor -define bmp:subtype=RGB565 -depth 16 "converted/$(basename "$img" .png).bmp"
        else
          magick "$img" -resize 480x800^ -gravity center -extent 480x800 -define bmp:format=bmp4 -type truecolor -define bmp:subtype=RGB565 -depth 16 "converted/$(basename "$img" .png).bmp"
        fi
      done

      ${pkgs.python313}/bin/python3 ${aml-imgpack} --pack bootlogos.bin converted/*.bmp
    '';

    installPhase = "mv bootlogos.bin $out";
  };
in
{
  system.build.aml-imgpack = aml-imgpack;
  system.build.bootlogos = bootlogos;
}
