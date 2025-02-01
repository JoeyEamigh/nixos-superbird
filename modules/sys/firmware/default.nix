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
  hardware.firmware = lib.mkIf cfg.bluetooth.enable [
    (pkgs.stdenv.mkDerivation {
      name = "broadcom-superbird-bluetooth";
      src = [ ./brcm ];
      phases = [ "installPhase" ];
      installPhase = ''
        mkdir -p $out/lib/firmware/brcm
        cp $src/* $out/lib/firmware/brcm/
      '';
    })
  ];

  systemd.services.superbird-firmware = lib.mkIf cfg.bluetooth.enable {
    enable = true;
    before = [ "bluetooth.service" ];
    requiredBy = [ "bluetooth.service" ];
    serviceConfig = {
      Type = "oneshot";
    };
    script = ''
      if [ ! -f /lib/firmware/brcm/BCM.hcd ] || [ ! -f /lib/firmware/brcm/BCM20703A2.hcd ]; then
        echo "firmware >>> bluetooth firmware not detected - setting up"

        mkdir -p /lib/firmware/brcm
        cp ${./brcm/BCM.hcd} /lib/firmware/brcm/BCM.hcd
        cp ${./brcm/BCM20703A2.hcd} /lib/firmware/brcm/BCM20703A2.hcd

        echo "firmware >>> bluetooth firmware set up!"
      fi
    '';
  };
}
