{
  config,
  pkgs,
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
          FastConnectable = true;
        };
      };
    };

    hardware.firmware = [
      (pkgs.stdenv.mkDerivation {
        name = "broadcom-superbird-bluetooth";
        src = [ ./firmware/brcm ];
        phases = [ "installPhase" ];
        installPhase = ''
          mkdir -p $out/lib/firmware/brcm
          cp $src/* $out/lib/firmware/brcm/
        '';
      })
    ];

    environment.systemPackages = with pkgs; [ libgpiod_1 ];

    systemd.services.bluetooth.wantedBy = [ "default.target" ];
    systemd.services.bluetooth-adapter = {
      enable = true;
      before = [ "bluetooth.service" ];
      requiredBy = [ "bluetooth.service" ];
      script = ''
        ${pkgs.libgpiod_1}/bin/gpioset 0 82=1
        sleep 1
        ${pkgs.bluez}/bin/btattach -P bcm -B /dev/ttyAML6
      '';
    };
  };
}
