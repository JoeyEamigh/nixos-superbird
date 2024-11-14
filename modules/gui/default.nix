{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.superbird;

  app = "${pkgs.writeScriptBin "start-cage-app" ''
    #!/usr/bin/env bash
    wlr-randr --output DSI-1 --transform 270

    exec ${cfg.gui.app}
  ''}/bin/start-cage-app";
in
{

  config = lib.mkIf cfg.gui.enable {
    environment.systemPackages = with pkgs; [ wlr-randr ];

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
        assertion = cfg.gui.app != null;
        message = "You must include an app when GUI is enabled.";
      }
    ];
  };
}
