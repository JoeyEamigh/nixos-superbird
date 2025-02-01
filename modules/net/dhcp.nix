{ ... }:
{
  services.dnsmasq = {
    enable = true;
    settings = {
      server = [
        "1.1.1.1"
        "8.8.8.8"
      ];

      interface = "usb0";
      local = "/superbird/";
      dhcp-range = "172.16.42.1,172.16.42.1,255.255.255.0,1m";
      dhcp-option = "option:router,172.16.42.1";
    };
  };
}
