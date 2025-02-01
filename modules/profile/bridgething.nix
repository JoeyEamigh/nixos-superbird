{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.superbird;
in
{
  config = lib.mkIf cfg.bridgething.enable {
    systemd.services."bridgething" = {
      enable = true;
      after = [ "bluetooth.service" ];
      before = [ "graphical.target" ];
      wants = [ "dbus.socket" ];
      wantedBy = [ "graphical.target" ];

      restartIfChanged = true;
      unitConfig.ConditionPathExists = "/dev/tty1";
      serviceConfig = {
        Type = "notify";
        ExecStart = "${pkgs.bridgething}/bin/bridgething";
        User = "superbird";

        IgnoreSIGPIPE = "no";
        StandardOutput = "journal";
        StandardError = "journal";
      };
      environment = {
        RUST_LOG = "bridgething=trace,bridgething::ws::connection::send=debug";
      };
    };
  };
}
