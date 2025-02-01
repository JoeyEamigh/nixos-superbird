{ ... }:
{
  security = {
    # enableWrappers = false;

    pam.services = {
      login = {
        allowNullPassword = true;

        text = ''
          # Account management.
          account sufficient pam_permit.so
          account required pam_unix.so # unix (order 10900)

          # Authentication management.
          auth sufficient pam_permit.so
          auth sufficient pam_rootok.so # rootok (order 10200)
          auth required pam_faillock.so # faillock (order 10400)
          auth sufficient pam_unix.so likeauth try_first_pass # unix (order 11600)
          auth required pam_deny.so # deny (order 12400)

          # Password management.
          password sufficient pam_unix.so nullok yescrypt # unix (order 10200)

          # Session management.
          session required pam_permit.so
          session required pam_env.so conffile=/etc/pam/environment readenv=0 # env (order 10100)
          session required pam_unix.so # unix (order 10200)
        '';
      };
      sshd = {
        allowNullPassword = true;
        text = ''
          # Account management.
          account sufficient pam_permit.so
          account required pam_unix.so # unix (order 10900)

          # Authentication management.
          auth sufficient pam_permit.so
          auth sufficient pam_unix.so likeauth nullok try_first_pass # unix (order 11600)
          auth required pam_deny.so # deny (order 12400)

          # Password management.
          password sufficient pam_unix.so nullok yescrypt # unix (order 10200)

          # Session management.
          session required pam_permit.so
          session required pam_env.so conffile=/etc/pam/environment readenv=0 # env (order 10100)
          session required pam_unix.so # unix (order 10200)
        '';
      };
    };

    sudo.extraConfig = ''
      %wheel	ALL=(root)	NOPASSWD: ALL
    '';
  };

  services.getty.autologinUser = "root";

  environment.etc."pam_debug".text = "";
}
