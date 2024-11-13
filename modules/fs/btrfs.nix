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
    btrfs-progs = pkgs.btrfs-progs.overrideAttrs (oldAttrs: {
      src = pkgs.fetchFromGitHub {
        owner = "kdave";
        repo = "btrfs-progs";
        # devel 2024.09.10; Remove v6.11 release.
        rev = "c75b2f2c77c9fdace08a57fe4515b45a4616fa21";
        hash = "sha256-PgispmDnulTDeNnuEDdFO8FGWlGx/e4cP8MQMd9opFw=";
      };

      patches = [
        ./mkfs-btrfs-force-root-ownership.patch
      ];
      postPatch = "";

      nativeBuildInputs = oldAttrs.nativeBuildInputs ++ [
        pkgs.autoconf
        pkgs.automake
      ];
      preConfigure = "./autogen.sh";

      version = "6.11.0.pre";
    });
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
