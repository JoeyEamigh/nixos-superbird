{
  lib,
  ...
}:
{
  imports = [
    ./fs
    ./gui
    ./installer
    ./net
    ./profile
  ];

  options.superbird = with lib; {
    bluetooth = {
      enable = mkOption {
        default = true;
        type = types.bool;
        description = "whether to enable Bluetooth support";
      };

      name = mkOption {
        default = "Superbird";
        type = types.str;
        description = "name the device broadcasts via Bluetooth";
      };
    };

    gui = {
      enable = mkOption {
        default = true;
        type = types.bool;
        description = "whether to enable cage to run gui applications";
      };

      app = mkOption {
        default = null;
        type = types.str;
        example = "\${pkgs.cog}/bin/cog https://example.com";
        description = "path to the application to run in cage";
      };
    };

    swap = {
      enable = mkOption {
        default = true;
        type = types.bool;
        description = "whether to enable a swapfile";
      };

      size = mkOption {
        default = 512;
        type = types.int;
        description = "size of the swapfile, in MiB";
      };
    };

    packages = {
      useful = mkOption {
        default = false;
        type = types.bool;
        description = "whether to enable some useful packages";
      };
    };

    qemu = mkOption {
      default = false;
      type = types.bool;
      description = "whether to build for qemu";
    };
  };

  config = {
    nixpkgs.overlays = [
      (self: super: {
        # patched version of cage that fixes window centering
        cage = super.cage.overrideAttrs (old: {
          patches = [
            (super.fetchpatch {
              url = "https://patch-diff.githubusercontent.com/raw/cage-kiosk/cage/pull/365.patch";
              hash = "sha256-Grap5a3+8JkxMGS2dFLcKrElDvjq9QKaLQqhL722keo=";
            })
          ];
        });
      })
      (self: super: {
        superbirdKernel =
          (super.linuxManualConfig {
            version = "6.6.43";
            modDirVersion = "6.6.43";
            # extraMeta.branch = "6.6.43";

            configfile = ./superbird_defconfig;
            allowImportFromDerivation = true;

            src = super.fetchFromGitHub {
              owner = "alexcaoys";
              repo = "linux-superbird-6.6.y";
              rev = "95c292d859f44efaffcea509fc2575d028d81458";
              sha256 = "sha256-Or1bWEJbckQ9u8GWLakNdRe1Vi3OXyR1WPB17I1F6lQ=";
            };

            kernelPatches = [ ];
          }).overrideAttrs
            (old: {
              nativeBuildInputs = old.nativeBuildInputs ++ [ super.ubootTools ];
              buildDTBs = false;
            });

        superbirdQemuKernel = super.linuxKernel.kernels.linux_6_6.override {
          structuredExtraConfig = with lib.kernel; {
            BTRFS_FS = yes;
            NLS = yes;
            NLS_DEFAULT = lib.mkForce (freeform "iso8859-1");
            NLS_CODEPAGE_437 = lib.mkForce yes;
            FAT_FS = yes;
            VFAT_FS = yes;
            FAT_DEFAULT_CODEPAGE = freeform "437";
            FAT_DEFAULT_IOCHARSET = freeform "ascii";
          };
        };
      })
    ];
  };
}
