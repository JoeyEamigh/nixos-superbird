{ pkgs, ... }:
let
  aml-envpack = pkgs.stdenv.mkDerivation {
    name = "aml-envpack.py";

    dontUnpack = true;
    installPhase = "cp ${./resources/aml-envpack.py} $out";
  };

  bootenv = pkgs.stdenv.mkDerivation {
    name = "bootenv.bin";

    dontUnpack = true;
    buildPhase = ''
      ${pkgs.python313}/bin/python3 ${aml-envpack} ${./resources/env.txt}
    '';

    installPhase = "mv env.bin $out";
  };

  bootenvtxt = pkgs.stdenv.mkDerivation {
    name = "env.txt";

    dontUnpack = true;
    buildPhase = ''
      ${pkgs.python313}/bin/python3 ${aml-envpack} -to env.txt ${./resources/env.txt}
    '';

    installPhase = "mv env.txt $out";
  };
in
{
  system.build.aml-envpack = aml-envpack;
  system.build.bootenv = bootenv;
  system.build.bootenvtxt = bootenvtxt;
}
