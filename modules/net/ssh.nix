{ ... }:
{
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "yes";
      PasswordAuthentication = true;
      PermitEmptyPasswords = "yes";
      UsePAM = false;
    };
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

  system.build.ed25519Key = ./ssh/ssh_host_ed25519_key;
}
