{ config, ... }:
let
  cfg = config.superbird;
in
{
  users = {
    users = {
      superbird = {
        isNormalUser = true;
        home = "/home/superbird";
        initialPassword = "superbird";
        description = "Superbird User";

        extraGroups = [
          "wheel"
          "networkmanager"
          "audio"
          "video"
          "input"
          "bluetooth"
        ];
        uid = 1000;

        openssh.authorizedKeys.keyFiles = [
          ../net/ssh/ssh_host_ed25519_key.pub
          ../net/ssh/ssh_host_rsa_key.pub
        ];
      };

      root.openssh.authorizedKeys.keyFiles = [
        ../net/ssh/ssh_host_ed25519_key.pub
        ../net/ssh/ssh_host_rsa_key.pub
      ];
    };

    groups.superbird.gid = 1000;
  };

  security.sudo.extraConfig = ''
    %wheel	ALL=(root)	NOPASSWD: ALL
  '';
}
