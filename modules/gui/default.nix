{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.superbird;

  chromeKiosk = ''
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
      --app=${cfg.gui.kiosk}
  '';

  app = "${pkgs.writeScriptBin "start-cage-app" ''
    #!/usr/bin/env bash
    wlr-randr --output DSI-1 --transform 270

    exec ${if cfg.gui.kiosk != null then chromeKiosk else cfg.gui.app}
  ''}/bin/start-cage-app";
in
{
  config = lib.mkIf cfg.gui.enable {
    environment.systemPackages = with pkgs; [
      wlr-randr
      fbset
    ];

    services.cage = {
      enable = true;
      user = "superbird";
      program = "${app}";
      extraArguments = [ "-d" ];
    };

    services.udev.packages = [
      (pkgs.writeTextFile {
        name = "touchscreen_udev";
        text = ''
          KERNEL=="event2", SUBSYSTEM=="input", ENV{LIBINPUT_CALIBRATION_MATRIX}="0 1 0 -1 0 1" ENV{WL_OUTPUT}="DSI-1"
        '';
        destination = "/etc/udev/rules.d/97-touchscreen.rules";
      })
    ];

    assertions = [
      {
        assertion = cfg.gui.app != null || cfg.gui.kiosk != null;
        message = "You must include an app or a kiosk site when GUI is enabled.";
      }
      {
        assertion = cfg.gui.app == null || cfg.gui.kiosk == null;
        message = "You cannot use both an app and a kiosk site.";
      }
    ];
  };
}
