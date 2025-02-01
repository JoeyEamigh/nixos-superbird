{ ... }:
{
  users = {
    users = {
      superbird = {
        isNormalUser = true;
        home = "/home/superbird";
        password = "superbird";
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

      root = {
        hashedPassword = "";

        openssh.authorizedKeys.keyFiles = [
          ../net/ssh/ssh_host_ed25519_key.pub
          ../net/ssh/ssh_host_rsa_key.pub
        ];
      };
    };

    mutableUsers = false;
    groups.superbird.gid = 1000;
  };
}
