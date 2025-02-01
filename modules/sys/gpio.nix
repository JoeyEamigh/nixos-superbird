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
  # environment.systemPackages = with pkgs; [ libgpiod_1 ];

  systemd.services.bluetooth-adapter = lib.mkIf cfg.bluetooth.enable {
    enable = true;
    before = [ "bluetooth.service" ];
    requiredBy = [ "bluetooth.service" ];
    serviceConfig = {
      Type = "notify";
    };
    script = ''
      GPIOX_17=493

      hw_reset_bt() {
        systemd-notify --status "Resetting GPIO pins..."

        echo -e "\n|-----Bluetooth HW reset-----|\n\n"
        if [ ! -f /sys/class/gpio/gpio493/direction ]; then
          echo ''${GPIOX_17} >/sys/class/gpio/export
          echo out >/sys/class/gpio/gpio493/direction
        fi

        # Pull the gpio pin down to reset chip
        echo 0 >/sys/class/gpio/gpio493/value
        sleep 0.1

        # Turn off reset
        echo 1 >/sys/class/gpio/gpio493/value

        # Give the chip some time to start
        sleep 0.3
      }

      echo -e "\n|-----Bluetooth STARTING-----|\n\n"
      systemd-notify --status "Starting..."

      hw_reset_bt

      systemd-notify --ready --status "Running!"
      ${pkgs.bluez}/bin/btattach -P bcm -B /dev/ttyS1
    '';
  };
}
