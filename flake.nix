{
  description = "superbird nixos configuration";

  nixConfig = {
    extra-substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
      "https://superbird.attic.claiborne.soy/superbird"
    ];
    extra-trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "superbird:r9Hm/REl7BEr6+9UQoS+nxzqxY2sKUhsDCNy5PGQbDU="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    {
      self,
      nixpkgs,
      ...
    }:
    let
      inherit (nixpkgs.lib) nixosSystem;
    in
    {
      nixosModules.superbird = import ./modules;

      nixosConfigurations = {
        cog-example = nixosSystem {
          system = "aarch64-linux";
          modules = [
            self.nixosModules.superbird
            ./examples/cog.nix
          ];
        };

        doom-example = nixosSystem {
          system = "aarch64-linux";
          modules = [
            self.nixosModules.superbird
            ./examples/doom.nix
          ];
        };

        headless-example = nixosSystem {
          system = "aarch64-linux";
          modules = [
            self.nixosModules.superbird
            ./examples/headless.nix
          ];
        };

        qemu-example = nixosSystem {
          system = "aarch64-linux";
          modules = [
            self.nixosModules.superbird
            ./examples/qemu.nix
          ];
        };
      };

      checks.aarch64-linux = self.packages.aarch64-linux;
      packages.aarch64-linux = {
        example-cog = self.nixosConfigurations.cog-example.config.system.build.installer;
        example-doom = self.nixosConfigurations.doom-example.config.system.build.installer;
        example-headless = self.nixosConfigurations.headless-example.config.system.build.installer;
      };
    };
}
