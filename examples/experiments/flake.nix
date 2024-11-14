{
  description = "NixOS Superbird configuration";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixos-superbird.url = "path:../../";
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
                # superbird.gui.app = "${pkgs.firefox}/bin/firefox";
                superbird.gui.app = ''
                  ${pkgs.ungoogled-chromium}/bin/chromium \
                    --ozone-platform-hint=auto \
                    --ozone-platform=wayland \
                    --no-sandbox \
                    --autoplay-policy=no-user-gesture-required \
                    --use-fake-ui-for-media-stream \
                    --use-fake-device-for-media-stream \
                    --disable-sync \
                    --remote-debugging-port=9222 \
                    --force-device-scale-factor=1.0 \
                    --pull-to-refresh=0 \
                    --disable-smooth-scrolling \
                    --disable-login-animations \
                    --disable-modal-animations \
                    --noerrdialogs \
                    --no-first-run \
                    --disable-infobars \
                    --fast \
                    --fast-start \
                    --disable-pinch \
                    --disable-translate \
                    --overscroll-history-navigation=0 \
                    --hide-scrollbars \
                    --disable-overlay-scrollbar \
                    --disable-features=OverlayScrollbar \
                    --disable-features=TranslateUI \
                    --disable-features=TouchpadOverscrollHistoryNavigation,OverscrollHistoryNavigation \
                    --password-store=basic \
                    --touch-events=enabled \
                    --ignore-certificate-errors \
                    --kiosk \
                    --app=https://motherfuckingwebsite.com/
                '';
                # superbird.gui.app = "${pkgs.cog}/bin/cog https://github.com/JoeyEamigh/nixos-superbird";
                superbird.packages.useful = true;

                # environment.systemPackages = [
                #   # useful
                #   pkgs.btop
                #   pkgs.neovim

                #   # fun
                #   pkgs.neofetch
                # ];

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
