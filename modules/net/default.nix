{ lib, ... }:
{
  imports = [
    ./dhcp.nix
    ./ssh.nix
    ./bluetooth.nix
  ];

  networking = {
    hostName = "superbird";
    interfaces.usb0.ipv4.addresses = [
      {
        address = "172.16.42.2";
        prefixLength = 24;
      }
    ];
    defaultGateway = {
      address = "172.16.42.1";
      interface = "usb0";
    };
    nameservers = [
      "1.1.1.1"
      "8.8.8.8"
    ];

    firewall.enable = lib.mkForce false;
    dhcpcd.wait = "background";
  };
}
