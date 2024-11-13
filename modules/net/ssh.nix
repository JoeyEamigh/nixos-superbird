{ config, pkgs, ... }:
let
  cfg = config.superbird;
in
{
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "yes";
      # PasswordAuthentication = true;
    };
    # extraConfig = ''
    #   PermitEmptyPasswords yes
    # '';
  };

  environment.etc."ssh/ssh_host_ed25519_key" = {
    source = ./ssh/ssh_host_ed25519_key;
    mode = "0600";
  };
  environment.etc."ssh/ssh_host_ed25519_key.pub" = {
    source = ./ssh/ssh_host_ed25519_key.pub;
    mode = "0644";
  };
  environment.etc."ssh/ssh_host_rsa_key" = {
    source = ./ssh/ssh_host_rsa_key;
    mode = "0600";
  };
  environment.etc."ssh/ssh_host_rsa_key.pub" = {
    source = ./ssh/ssh_host_rsa_key.pub;
    mode = "0644";
  };

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

  system.build.ed25519Key = ./ssh/ssh_host_ed25519_key;
}
