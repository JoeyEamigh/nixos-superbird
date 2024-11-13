{
  description = "NixOS Superbird configuration";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    nixos-superbird.url = "path:../../";
    # nixos-superbird.url = "github:joeyeamigh/nixos-superbird/main";

    deploy-rs.url = "github:serokell/deploy-rs";
  };

  outputs =
    {
      self,
      nixpkgs,
      nixos-superbird,
      deploy-rs,
    }:
    let
      inherit (nixpkgs.lib) nixosSystem;
    in
    {
      nixosConfigurations = {
        superbird = nixosSystem {
          system = "aarch64-linux";
          modules = [
            nixos-superbird.nixosModules.superbird
            (
              { pkgs, ... }:
              {
                superbird.gui.app = "${pkgs.cog}/bin/cog https://github.com/JoeyEamigh/nixos-superbird";
                system.stateVersion = "24.11";
              }
            )
          ];
        };
      };

      deploy.nodes = {
        superbird = {
          hostname = "172.16.42.2";
          fastConnection = false;
          remoteBuild = false;
          profiles.system = {
            sshUser = "root";
            path = deploy-rs.lib.aarch64-linux.activate.nixos self.nixosConfigurations.superbird;
            user = "root";
            sshOpts = [
              "-i"
              "${self.nixosConfigurations.superbird.config.system.build.ed25519Key}"
            ];
          };
        };
      };
    };
}
