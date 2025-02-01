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
  services.udev.packages = [
    (pkgs.writeTextFile {
      name = "keys_udev";
      text = ''
        KERNEL=="event0", SUBSYSTEM=="input", GROUP="input", MODE="0660", ENV{ID_INPUT_KEYBOARD}="1", ENV{LIBINPUT_DEVICE_GROUP}="gpio-keys"
      '';
      destination = "/etc/udev/rules.d/97-keys.rules";
    })
    (pkgs.writeTextFile {
      name = "rotary_udev";
      text = ''
        KERNEL=="event1", SUBSYSTEM=="input", GROUP="input", MODE="0660", ENV{ID_INPUT_KEYBOARD}="1", ENV{LIBINPUT_DEVICE_GROUP}="rotary-input"
      '';
      destination = "/etc/udev/rules.d/97-rotary.rules";
    })

    # don't need touch screen if there's no gui lol
    (lib.mkIf cfg.gui.enable (
      pkgs.writeTextFile {
        name = "touchscreen_udev";
        text = ''
          KERNEL=="event2", SUBSYSTEM=="input", ENV{LIBINPUT_CALIBRATION_MATRIX}="0 1 0 -1 0 1" ENV{WL_OUTPUT}="DSI-1"
        '';
        destination = "/etc/udev/rules.d/97-touchscreen.rules";
      }
    ))
  ];
}
