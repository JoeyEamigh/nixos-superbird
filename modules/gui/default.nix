{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.superbird;

  isWebapp = cfg.gui.webapp != null || cfg.gui.superbird-webapp == true;

  weston =
    if cfg.gpu.enable then
      pkgs.callPackage ./weston.nix {
        libMali = config.drivers.libMali;
        xwaylandSupport = false;
        remotingSupport = false;
        pipewireSupport = false;
        vncSupport = false;
      }
    else
      pkgs.weston;

  # --in-process-gpu \
  # --no-sandbox \
  # --ozone-platform-hint=auto \
  # --ozone-platform=wayland \
  # --enable-wayland-ime \

  chromeKiosk = urlStatement: ''
    ${pkgs.chromium}/bin/chromium \
      --no-gpu \
      --disable-gpu \
      --disable-gpu-compositing \
      --ozone-platform-hint=auto \
      --ozone-platform=wayland \
      --enable-wayland-ime \
      --no-sandbox \
      --autoplay-policy=no-user-gesture-required \
      --use-fake-ui-for-media-stream \
      --use-fake-device-for-media-stream \
      --disable-sync \
      --remote-debugging-address=172.16.42.2 \
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
      --app=${urlStatement}
  '';

  app = "${pkgs.writeScriptBin "start-weston-app" ''
    #!/usr/bin/env bash

    exec ${
      if cfg.gui.kiosk_url != null then
        chromeKiosk "$(cat /etc/kiosk_url)"
      else if isWebapp then
        chromeKiosk "http://127.0.0.1:80"
      else if cfg.gui.app != null then # prevent a null coercion
        cfg.gui.app
      else
        ""
    }
  ''}/bin/start-weston-app";

in
{
  config = lib.mkIf cfg.gui.enable {
    hardware.graphics = {
      enable = true;
      package = if cfg.gpu.enable then config.drivers.libMali else pkgs.mesa.drivers;
      extraPackages =
        with pkgs;
        [
          libvdpau-va-gl
          vaapiVdpau
          libdrm
        ]
        ++ (if cfg.gpu.enable then [ stdenv.cc.cc.lib ] else [ libglvnd ]);
    };

    environment.systemPackages =
      with pkgs;
      [ weston ]
      ++ lib.optionals (!cfg.gpu.enable) [
        libglvnd
        mesa
        mesa.drivers
      ];

    environment.sessionVariables = {
      FONTCONFIG_FILE = "${pkgs.fontconfig.out}/etc/fonts/fonts.conf";
      FONTCONFIG_PATH = "${pkgs.fontconfig.out}/etc/fonts";
    };

    environment.etc."kiosk_url" = lib.mkIf (cfg.gui.kiosk_url != null) { text = cfg.gui.kiosk_url; };

    services.static-web-server = lib.mkIf isWebapp {
      enable = true;
      listen = "0.0.0.0:80";
      root = if (cfg.gui.superbird-webapp == true) then pkgs.superbird-webapp else cfg.gui.webapp;
      configuration = {
        general = {
          cache-control-headers = false;
          compression = false;
        };
      };
    };

    environment.etc."weston/weston.ini".source = ./resources/weston.ini;
    environment.etc."weston/background.png".source =
      if cfg.boot.logo != null then cfg.boot.logo else ../boot/bootfs/resources/images/bootup.png;
    environment.etc."weston/keys".source = ./resources/keys;

    systemd.services."weston-tty1" = {
      enable = true;
      after = [
        "systemd-user-sessions.service"
        "plymouth-start.service"
        "plymouth-quit.service"
        "systemd-logind.service"
        "getty@tty1.service"
      ] ++ lib.optionals (isWebapp) [ "static-web-server.service" ];
      before = [ "graphical.target" ];
      wants = [
        "dbus.socket"
        "systemd-logind.service"
        "plymouth-quit.service"
      ];
      wantedBy = [ "graphical.target" ];
      conflicts = [ "getty@tty1.service" ];

      restartIfChanged = true;
      unitConfig.ConditionPathExists = "/dev/tty1";
      serviceConfig = {
        ExecStart = ''
          ${weston}/bin/weston \
            --config /etc/weston/weston.ini \
            -- ${app}
        '';
        # ExecStart = ''
        #   ${weston}/bin/weston \
        #     --config /etc/weston/weston.ini
        # '';
        User = "superbird";

        IgnoreSIGPIPE = "no";
        UtmpIdentifier = "%n";
        UtmpMode = "user";
        TTYPath = "/dev/tty1";
        TTYReset = "yes";
        TTYVHangup = "yes";
        TTYVTDisallocate = "yes";
        StandardInput = "tty-fail";
        StandardOutput = "journal";
        StandardError = "journal";
        PAMName = "weston";
      };
      environment = {
        XDG_SESSION_TYPE = "wayland";
        # EGL_LOG_LEVEL = "debug";
        # WAYLAND_DEBUG = "1";
      };
    };

    security.polkit.enable = true;
    security.pam.services.weston.text = ''
      auth    sufficient pam_permit.so
      auth    required   pam_unix.so nullok

      account sufficient pam_permit.so
      account required   pam_unix.so

      password sufficient pam_unix.so nullok yescrypt

      session required   pam_permit.so
      session required   pam_unix.so
      session required   pam_env.so conffile=/etc/pam/environment readenv=0
      session required   ${config.systemd.package}/lib/security/pam_systemd.so
    '';
    security.pam.services.weston-remote-access.text = ''
      auth    sufficient pam_permit.so
      auth    required   pam_unix.so nullok

      account sufficient pam_permit.so
      account required   pam_unix.so

      password sufficient pam_unix.so nullok yescrypt

      session required   pam_permit.so
      session required   pam_unix.so
      session required   pam_env.so conffile=/etc/pam/environment readenv=0
      session required   ${config.systemd.package}/lib/security/pam_systemd.so
    '';

    systemd.targets.graphical.wants = [ "weston-tty1.service" ];
    systemd.defaultUnit = "graphical.target";

    programs.dconf.enable = true;
    programs.xwayland.enable = cfg.gui.xorg;
    services.xserver.desktopManager.runXdgAutostartIfNone = cfg.gui.xorg;

    systemd.tmpfiles.rules = lib.mkIf cfg.gui.xorg [
      "d /tmp/.X11-unix 1777 root root"
      "d /swap 0600 root root"
    ];

    assertions =
      let
        guiOptions = [
          cfg.gui.kiosk_url
          cfg.gui.webapp
          cfg.gui.superbird-webapp
          cfg.gui.app
        ];

        enabledOptions = builtins.filter (x: x != null && x != false) guiOptions;
      in
      [
        {
          assertion = builtins.length enabledOptions > 0;
          message = "You must enable one of the gui options.";
        }
        {
          assertion = builtins.length enabledOptions == 1;
          message = "You must use one and only one prebaked gui option.";
        }
      ];
  };
}
