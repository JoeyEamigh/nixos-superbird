{
  self,
  config,
  pkgs,
  ...
}:
let
  cfg = config.superbird;
  src = self.inputs.nixos-superbird;

  meta = pkgs.replaceVars ./resources/nixos-superbird.json {
    inherit (cfg) name version description;

    owner = if self ? owner then self.owner else "";
    repo = if self ? repo then self.repo else "";
    rev = if self ? rev then self.rev else "";
    ref = if self ? ref then self.ref else "";
    type = if self ? type then self.type else "";
    lastModified = if self ? lastModified then self.lastModified else "";
    narHash = if self ? narHash then self.narHash else "";

    nixos-superbird-owner = if src ? owner then src.owner else "JoeyEamigh";
    nixos-superbird-repo = if src ? repo then src.repo else "nixos-superbird";
    nixos-superbird-rev = if src ? rev then src.rev else "";
    nixos-superbird-ref = if src ? ref then src.ref else "";
    nixos-superbird-type = if src ? type then src.type else "github";
    nixos-superbird-url =
      if src ? url then src.url else "https://github.com/JoeyEamigh/nixos-superbird";
    nixos-superbird-lastModified = if src ? lastModified then src.lastModified else "";
    nixos-superbird-narHash = if src ? narHash then src.narHash else "";
  };
in
{
  system.build.nixos-superbird-json = meta;
  environment.etc."superbird".source = meta;
  # services.earlyoom = {
  #   enable = true;
  #   enableNotifications = true;
  # };

  systemd.services.superbird-init = {
    enable = true;
    wantedBy = [ "sysinit.target" ];
    requiredBy = [
      "bluetooth-adapter.service"
      "bluetooth.service"
      "superbird-firmware.service"
      "sysinit.target"
    ];
    serviceConfig = {
      Type = "oneshot";
    };
    restartTriggers = [ config.environment.etc."superbird".source ];
    script = ''
      # serial="$(${pkgs.util-linux}/bin/hexdump -s 18 -n 12 -e '12/1 "%c"' /sys/bus/nvmem/devices/efuse0/nvmem)"
      # bt_mac="$(${pkgs.util-linux}/bin/hexdump -s 6 -n 6 -e '6/1 "%02X " "\n"' /sys/bus/nvmem/devices/efuse0/nvmem | ${pkgs.gawk}/bin/awk '{printf "%s:%s:%s:%s:%s:%s\n", $1, $2, $3, $4, $5, $6}')"

      # sed -i "s/\"btMac\": \"\"/\"btMac\": \"$bt_mac\"/" /etc/superbird
      # sed -i "s/\"serialNumber\": \"\"/\"serialNumber\": \"$serial\"/" /etc/superbird

      # mkdir -p /sys/class/efuse
      # echo "$serial" > /sys/class/efuse/usid
      # printf '\n0x00: %s %s %s %s %s %s \n' $(echo "$bt_mac" | tr '[:upper:]' '[:lower:]' | tr ':' ' ') > /sys/class/efuse/mac_bt

      full_serial="$(cat /sys/class/efuse/usid)"
      serial="$(cat /sys/class/efuse/usid | tail -c 5)"
      bt_mac="$(${pkgs.gawk}/bin/awk -F: '/0x00/ { split(toupper($2), s, " ") ; printf("%s:%s:%s:%s:%s:%s\n", s[1], s[2], s[3], s[4], s[5], s[6]) }' /sys/class/efuse/mac_bt)"
      if [ ''${#serial} -eq 4 ] && [ ''${#bt_mac} -eq 17 ]; then
        bt_settings_path="/var/lib/bluetooth/''${bt_mac}"
        if [ ! -f "''${bt_settings_path}/settings" ]; then
          mkdir -p "''${bt_settings_path}"
          printf "[General]\nAlias=Car Thing (SN: ''${serial})\n" >"''${bt_settings_path}/settings"
        fi
      else
        echo "Invalid serial or Bluetooth MAC address, falling back to Bluetooth device name \"Car Thing\": serial: \"''${full_serial}\", BT MAC: \"''${bt_mac}\""
      fi

      sed -i "s/\"btMac\": \"\"/\"btMac\": \"$bt_mac\"/" /etc/superbird
      sed -i "s/\"serialNumber\": \"\"/\"serialNumber\": \"$serial\"/" /etc/superbird

      bt_settings_path="/var/lib/bluetooth/$bt_mac"
      if [ ! -f "$bt_settings_path/settings" ]; then
        mkdir -p "$bt_settings_path"
        printf "[General]\nAlias=${cfg.bluetooth.name}\n" > "$bt_settings_path/settings"
      fi
    '';
  };
}
