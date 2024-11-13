{
  config,
  pkgs,
  lib,
  ...
}:
{
  environment.systemPackages = with pkgs; [ btrfs-progs ];

  system.build.btrfs = pkgs.callPackage ./make-btrfs-fs.nix {
    volumeLabel = "root";
    storePaths = config.system.build.toplevel;
    btrfs-progs = pkgs.btrfs-progs-force-root-ownership;
    populateImageCommands = ''
      mkdir -p ./files/bin
      cp ${config.system.build.toplevel}/prepare-root ./files/bin/init
    '';
    subvolMap =
      let
        fileSystems = builtins.filter (
          fs: (builtins.any (opt: lib.hasPrefix "subvol=" opt) fs.options)
        ) config.system.build.fileSystems;
        stripSubVolOption = opt: lib.removePrefix "subvol=" opt;
        getSubVolOption =
          opts: stripSubVolOption (builtins.head (builtins.filter (opt: lib.hasPrefix "subvol=" opt) opts));
        subvolMap = builtins.listToAttrs (
          builtins.map (fs: {
            name = "${fs.mountPoint}";
            value = "${getSubVolOption fs.options}";
          }) fileSystems
        );
      in
      subvolMap;
  };
}
