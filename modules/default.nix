{
  nixpkgs,
  nixpkgs2405,
  # bridgething,
  superbird-webapp,
}:
{
  self,
  config,
  pkgs,
  lib,
  ...
}:
let
  currentStateVersion = "0.2";
in
{
  imports = [
    ./boot
    ./gui
    ./initrd
    ./installer
    ./net
    ./profile
    ./sys
  ];

  options.superbird = with lib; {
    name = mkOption {
      default = "nixos-superbird";
      type = types.str;
      description = "name of the application built with nixos-superbird";
    };

    version = mkOption {
      default = "v1.0.0";
      type = types.str;
      description = "version of the application built with nixos-superbird";
    };

    description = mkOption {
      default = "NixOS for the Spotify Car Thing";
      type = types.str;
      description = "description of the application built with nixos-superbird";
    };

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
        description = "whether to enable weston to run gui applications";
      };

      xorg = mkOption {
        default = false;
        type = types.bool;
        description = "whether to enable xorg for xwayland";
      };

      kiosk_url = mkOption {
        default = null;
        type = types.nullOr types.str;
        example = "https://github.com/JoeyEamigh/nixos-superbird";
        description = "website to place into chromium kiosk mode";
      };

      webapp = mkOption {
        default = null;
        type = types.nullOr types.path;
        example = "./path/to/webapp/files";
        description = "path to files to be hosted and displayed in chrome";
      };

      superbird-webapp = mkOption {
        default = null;
        type = types.nullOr types.bool;
        description = "whether to enable the original spotify webapp";
      };

      app = mkOption {
        default = null;
        type = types.nullOr types.str;
        example = "\${pkgs.cog}/bin/cog https://github.com/JoeyEamigh/nixos-superbird";
        description = "path to the application to run in weston";
      };
    };

    bridgething = {
      enable = mkOption {
        default = true;
        type = types.bool;
        description = "whether to enable bridgething";
      };
    };

    gpu = {
      enable = mkOption {
        default = false;
        type = types.bool;
        description = "whether to enable the gpu";
      };
    };

    swap = {
      enable = mkOption {
        default = true;
        type = types.bool;
        description = "whether to enable a swapfile";
      };

      size = mkOption {
        default = 256;
        type = types.int;
        description = "size of the swapfile, in MiB";
      };
    };

    boot = {
      logo =
        let
          png = mkOptionType {
            name = "png";
            descriptionClass = "noun";
            check =
              x:
              isStringLike x
              && builtins.substring 0 1 (toString x) == "/"
              && builtins.match ".*\\.png$" (toString x) != null;
            merge = mergeEqualOption;
          };
        in
        mkOption {
          default = null;
          type = types.nullOr png;
          description = "custom bootlogo for linux. NOTE THAT IF THIS OPTION IS USED, YOU MUST CREDIT nixos-superbird AND Thing Labs";
        };
    };

    packages = {
      nix = mkOption {
        default = true;
        type = types.bool;
        description = "whether to enable nix itself to be used as a package manager";
      };

      useful = mkOption {
        default = false;
        type = types.bool;
        description = "whether to enable some useful packages";
      };
    };

    legacy-installer = {
      enable = mkOption {
        default = false;
        type = types.bool;
        description = "whether the legacy installer is enabled.";
      };
    };

    installer = {
      manualScript = mkOption {
        default = false;
        type = types.bool;
        description = "whether the manual script is bundled with the terbium installer.";
      };
    };

    stateVersion = mkOption {
      type = types.enum [
        "null"
        currentStateVersion
      ];
      default = "null";
      description = "version of nixos-superbird you are using (alerts to breaking changes)";
    };

    # src = mkOption {
    #   type = types.attrs;
    #   default = self.inputs.nixos-superbird;
    #   description = "src of nixos-superbird source repo. do not override this!";
    # };

    # proj = mkOption {
    #   type = types.attrs;
    #   default = self;
    #   description = "project that is building with nixos-superbird. do not override this!";
    # };
  };

  config = {
    assertions = [
      {
        assertion = config.superbird.stateVersion == currentStateVersion;
        message = ''
          BREAKING CHANGES HAVE OCCURRED!

          The current version of this module is ${currentStateVersion},
          but you passed in `stateVersion` ${config.superbird.stateVersion}.

          This means that there have been breaking changes in this module.
          Please visit https://github.com/JoeyEamigh/nixos-superbird to see what changed.
        '';
      }
      {
        assertion = builtins.isAttrs self;
        message = "PLEASE PROVIDE `self` IN `specialArgs` AS SHOWN IN THE README - `specialArgs = { inherit self; };`";
      }
      {
        assertion = self ? inputs && self.inputs ? nixos-superbird;
        message = "Please ensure that the nixos-superbird import is named 'nixos-superbird' in your flake inputs.";
      }
    ];

    warnings =
      [ ]
      ++ lib.optionals (config.superbird.gpu.enable) [
        "GPU IS BROKEN NOW AND WILL BE BROKEN FOREVER UNLESS SOMEONE ADDS SUPPORT FOR THIS SPECIFIC G31 TO PANFROST. DO NOT USE THIS OPTION."
      ]
      ++ lib.optionals (config.superbird.boot.logo != null) [
        "CUSTOM BOOTLOGO IS SET - YOU ARE NOW ON THE HOOK FOR STRICTER CREDIT ATTRIBUTION REQUIREMENTS - CHECK THE README"
      ];

    # _module.args = {
    #   src = builtins.getFlake (toString ../.);
    #   proj = self;
    # };

    nixpkgs.overlays = [
      # (self: super: { bridgething = bridgething.packages.${super.system}.bridgething; })
      (self: super: { superbird-webapp = superbird-webapp.packages.${super.system}.superbird-webapp; })
      (self: super: { pkgs2405 = import nixpkgs2405 { system = "aarch64-linux"; }; })
      (self: super: {
        superbirdKernel =
          (super.pkgs2405.callPackage ./sys/kernel/kernel.nix
            {
              stdenv = super.pkgs2405.gcc6Stdenv;
            }
            {
              pname = "spotify-kernel";
              version = "4.9.113";
              modDirVersion = "4.9.113";
              extraMeta.branch = "main";

              configfile = ./sys/kernel/superbird_defconfig;
              allowImportFromDerivation = true;

              src = super.pkgs2405.fetchFromGitHub {
                owner = "JoeyEamigh";
                repo = "spotify-kernel";
                rev = "295ca0144aca4cebf7a4ab21e73d7395013315d2";
                sha256 = "sha256-EijtE9AhRBciFLK3ItdjiV02D1wBj8Nrwmavy3ZjiMI=";
              };

              kernelPatches = [ ];
            }
          ).overrideAttrs
            (old: {
              nativeBuildInputs = old.nativeBuildInputs ++ [ super.pkgs2405.ubootTools ];
              buildDTBs = true;
            });
      })
    ];
  };
}
