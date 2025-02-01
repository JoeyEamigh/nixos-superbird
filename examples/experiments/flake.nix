{
  description = "NixOS Superbird configuration";
  inputs = {
    nixos-superbird.url = "path:../../";
    nixpkgs.follows = "nixos-superbird/nixpkgs";
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
          specialArgs = {
            inherit self;
          };
          modules = [
            nixos-superbird.nixosModules.superbird
            (
              { pkgs, modulesPath, ... }:
              {
                superbird.gpu.enable = false;
                superbird.gui.xorg = false;

                # superbird.gui.superbird-webapp = true;
                superbird.gui.kiosk_url = "https://nocturne.brandons.place";
                superbird.packages.useful = true;
                superbird.installer.manualScript = true;

                superbird.stateVersion = "0.2";
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
          };
        };
      };
    };
}
