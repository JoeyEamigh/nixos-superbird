{
  config,
  lib,
  ...
}:
let
  cfg = config.superbird;
in
{
  config = lib.mkIf cfg.bluetooth.enable {
    environment.etc."machine-info".text = "PRETTY_HOSTNAME=${cfg.bluetooth.name}";

    hardware.bluetooth = {
      enable = true;
      powerOnBoot = false;
      settings = {
        General = {
          Name = cfg.bluetooth.name;
          Experimental = true;
          KernelExperimental = true;
          FastConnectable = true;
          JustWorksRepairing = "always";
        };
      };
    };

    systemd.services.bluetooth.wantedBy = [ "default.target" ];
  };
}
