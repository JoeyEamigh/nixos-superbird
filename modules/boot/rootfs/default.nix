{
  config,
  pkgs,
  ...
}:
let
  cfg = config.superbird;
in
{
  system.build.squashfs = pkgs.callPackage ./make-squashfs.nix {
    fileName = "nix-store";
    storeContents = [ config.system.build.toplevel ];
  };

  system.build.ext4 =
    if cfg.system.squashfs then
      pkgs.callPackage ./make-ext4-w-squash-fs.nix {
        volumeLabel = "NixOS";
        squashfs = config.system.build.squashfs;
        populateImageCommands = ''
          touch ./files/firstboot

          mkdir -p ./files/bin
          cp ${config.system.build.toplevel}/init ./files/bin/init
        '';
      }
    else
      pkgs.callPackage ./make-ext4-fs.nix {
        volumeLabel = "NixOS";
        storePaths = config.system.build.toplevel;
        populateImageCommands = ''
          touch ./files/firstboot

          mkdir -p ./files/bin
          cp ${config.system.build.toplevel}/init ./files/bin/init
        '';
      };

  system.build.tarball = pkgs.callPackage ./make-tarball.nix {
    storePaths = config.system.build.toplevel;
    populateImageCommands = ''
      touch ./files/firstboot

      mkdir -p ./files/bin
      cp ${config.system.build.toplevel}/init ./files/bin/init
    '';
  };
}
