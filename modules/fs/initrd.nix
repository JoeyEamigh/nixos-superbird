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
  boot.initrd = {
    compressor = "cat";

    systemd = {
      enable = true;
      emergencyAccess = true;
      network.enable = true;

      services."systemd-networkd".environment.SYSTEMD_LOG_LEVEL = "debug";

      initrdBin = with pkgs; [
        parted
        dosfstools
        btrfs-progs
        iproute2
        iputils
        vim
      ];

      users.root.shell = "/bin/bash";

      contents = {
        "/superbird/init".source = ./resources/initrd.sh;
        "/superbird/ampart-v1.4-aarch64-static".source = ./resources/ampart-v1.4-aarch64-static;
        "/superbird/decrypted.dtb".source = ./resources/stock_dtb.img;
        "/superbird/bootloader.img".source = ./resources/bootloader.img;
        "/superbird/Image".source = "${config.system.build.kernel}/Image";
        "/superbird/superbird.dtb".source = ./resources/meson-g12a-superbird.dtb;
        "/superbird/bootargs.txt".source = ./resources/env_p2.txt;

        "/etc/ssh/ssh_host_ed25519_key".source = ../net/ssh/ssh_host_ed25519_key;
        "/etc/ssh/ssh_host_rsa_key".source = ../net/ssh/ssh_host_rsa_key;
      };
    };

    network = {
      enable = true;
      ssh = {
        enable = true;
        port = 22;
        hostKeys = [
          ../net/ssh/ssh_host_rsa_key
          ../net/ssh/ssh_host_ed25519_key
        ];
        authorizedKeys = [ "ssh-rsa nokeysneeded" ];
      };
    };

    supportedFilesystems = lib.mkForce [
      "vfat"
      "btrfs"
    ];
    availableKernelModules = lib.mkForce [
      "loop"
      "overlay"
    ];
  };

  system.build.initrd =
    let
      modules = [
        "loop"
        "overlay"
      ];
      modulesClosure = pkgs.makeModulesClosure {
        rootModules = modules;
        kernel = config.system.modulesTree;
        firmware = config.hardware.firmware;
        allowMissing = false;
      };
    in
    pkgs.makeInitrd {
      compressor = "gzip";
      makeUInitrd = true;

      prepend = [ "${config.system.build.initialRamdisk}/initrd" ];

      contents = [
        {
          object = modulesClosure;
          symlink = "/lib";
        }
      ];
    };
}
