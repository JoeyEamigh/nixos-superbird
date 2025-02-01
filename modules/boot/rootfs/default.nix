{
  config,
  pkgs,
  ...
}:
let
  cfg = config.superbird;
in
{
  system.build.ext4 = pkgs.callPackage ./make-ext4-fs.nix {
    volumeLabel = "NixOS";
    storePaths = config.system.build.toplevel;
    populateImageCommands = ''
      mkdir -p ./files/bin
      cp ${config.system.build.toplevel}/${
        if cfg.legacy-installer.enable then "prepare-root" else "init"
      } ./files/bin/init
    '';
  };

  system.build.tarball = pkgs.callPackage ./make-tarball.nix {
    storePaths = config.system.build.toplevel;
    populateImageCommands = ''
      mkdir -p ./files/bin
      cp ${config.system.build.toplevel}/${
        if cfg.legacy-installer.enable then "prepare-root" else "init"
      } ./files/bin/init
    '';
  };
}
