# NixOS for the Spotify Car Thing

`nixos-superbird` is a project to help build custom Linux images for the Spotify Car Thing and easily install them. This is the first project to democratize Linux for the Superbird, and by far the easiest way to attain full control of the Car Thing.

**If you would like to support the development of `nixos-superbird`, please consider sending us any old Car Things you may have lying around. They are rather expensive now.**

Join the [Thing Labs Discord](https://tl.mt/d) for the most up-to-date information on Car Thing Hacking!

## Credits and Attribution

If you are using `nixos-superbird` to build a custom Car Thing image, you MUST credit both `nixos-superbird` and Thing Labs. Additionally, if you build your app with [`BridgeThing`](https://github.com/JoeyEamigh/bridgething), you must credit the `BridgeThing` repo as well. This credit can be done on a settings or about page, but must not be hidden.

Credit to Joey Eamigh and Thing Labs for the firmware image must be provided in a user-facing location in your application. If you change the bootlogo, it must not be harder to find than your own credits and version number.

The intention of this clause is to support and motivate the Thing Labs team, not undermine your own work.

## Features

- [x] fully customizable NixOS
- [x] easy installation via Terbium
- [x] support for Bluetooth and Bluetooth PAN (tetherless Car Thing, anyone?)
- [x] `cdc_ncm`-based networking for tethered Linux, Windows, and MacOS support
- [x] built-in dhcp server for zero-config networking
- [x] support for live deployments without rebuilding (thanks nix!)
- [x] modified spotify kernel for maximum compatibility
- [x] first-class [`BridgeThing`](https://github.com/JoeyEamigh/bridgething) support
- [x] integrated tooling to host your own webapp on-device

## Quick Setup

Head on over to <https://github.com/JoeyEamigh/nixos-superbird-template> and clone the template to quickly get started with `nixos-superbird`!

## Setup

To use `nixos-superbird`, you must have either Nix installed on your computer, or have Docker installed. If you are not on an `aarch64-linux` machine (most of you), then you also need to have QEMU binfmt set up. Look up how to set that up on your distro.

- check if it's installed by running `ls /proc/sys/fs/binfmt_misc/`
- on Arch, you can just run `pacman -S qemu-user-static-binfmt`

Once that is set up, add this line to your `/etc/nix/nix.conf` and restart the Nix daemon:

```none
extra-platforms = aarch64-linux
```

The most basic form of using `nixos-superbird` is a single `flake.nix` file.

```nix
{
  description = "NixOS Superbird configuration";
  inputs = {
    nixos-superbird.url = "github:joeyeamigh/nixos-superbird/main";
    nixpkgs.follows = "nixos-superbird/nixpkgs"; # if you need newer versions of apps you can override or PR this repo
  };

  outputs =
    {
      self,
      nixpkgs,
      nixos-superbird,
    }:
    let
      inherit (nixpkgs.lib) nixosSystem;
    in
    {
      nixosConfigurations = {
        superbird = nixosSystem {
          system = "aarch64-linux";
          specialArgs = { inherit self; };
          modules = [
            nixos-superbird.nixosModules.superbird
            (
              { ... }:
              {
                superbird.gui.kiosk_url = "https://github.com/JoeyEamigh/nixos-superbird";

                superbird.stateVersion = "0.2";
                system.stateVersion = "24.11";
              }
            )
          ];
        };
      };
    };
}
```

I would recommend basing your config off of the [`./examples/flake/`](./examples/flake/) directory. It contains a basic flake along with [`deploy-rs`](https://github.com/serokell/deploy-rs) for easy updates without reflashing your Superbird, and a `Justfile` with helpful scripts.

To build, run:

```sh
nix build '.#nixosConfigurations.superbird.config.system.build.installer'
```

Once you have Nix installed on your Superbird, you can make changes to your flake and run the `push` script in the `Justfile` to update the device without reflashing.

Read through the [`Justfile`](./examples/flake/Justfile) in `./examples/flake` to see all steps to build an installer.

## Configuration

To make this flake as easy to use as possible, not many things are directly configurable at the moment. You can obviously override anything I have set with `lib.mkForce`. You can view all superbird configuration options in [`./modules/default.nix`](./modules/default.nix), and the defaults are listed below. If you would like to add more config options, feel free to PR with the config and an example.

```nix
{
  superbird = {
    name = "nixos-superbird"; # name of the application built with nixos-superbird
    version = "v1.0.0"; # version of the application built with nixos-superbird
    description = "NixOS for the Spotify Car Thing"; # description of the application built with nixos-superbird

    bluetooth = {
      enable = true; # whether bluetooth is enabled
      name = "Superbird"; # name of the device as it broadcasts over bluetooth
    };

    gui = {
      enable = true; # whether weston is enabled

      # --- only one of the below options can be enabled at a time!! ---
      kiosk_url = null; # website to place into chromium kiosk mode
      webapp = null; # path to files to be hosted and displayed in chrome
      superbird-webapp = null; # whether to enable the original spotify webapp
      app = null; #path to the application to run in weston
    };

    swap = {
      enable = true; # whether to create a swapfile
      size = 256; # size of said swapfile in MiB
    };

    boot = {
      # path to png bootlogo to replace the default Thing Labs logo.
      # NOTE: if you replace the Thing Labs logo, please ensure that credit to nixos-superbird
      # and ThingLabs is VERY PROMINENTLY displayed in your application's settings or about page.
      logo = null;
    };

    system = {
      squashfs = true; # whether to use a squashfs as the root file system or ext4 (squashfs is about 1/3 the size but both fit)
    };

    installer = {
      manualScript = false; # whether the manual script is bundled with the terbium installer.
    };

    stateVersion = "0.2"; # version of nixos-superbird you are using (alerts to breaking changes)
  };
}
```

## Installation

Once you have built an installer, it will be output to `./result`. Due to the fact that Nix cannot mount loop devices in the build sandbox, you must build the boot partition. There is a script that will do that for you.

```sh
sudo ./scripts/make-bootfs.sh
```

To make a Terbium installer, run the following commands instead:

```bash
#!/usr/bin/env bash
set -euo pipefail

nix build '.#nixosConfigurations.superbird.config.system.build.installer' -j$(nproc) --show-trace
echo "kernel is $(stat -Lc%s -- result/builder/kernel | numfmt --to=iec)"
echo "rootfs is $(stat -Lc%s -- result/rootfs.img | numfmt --to=iec)"

sudo rm -rf ./out
mkdir ./out
cp -r ./result/* ./out/
chown -R $(whoami):$(whoami) ./out
cd ./out

sudo ./scripts/make-bootfs.sh
echo "bootfs built!"

cd ./out/
zip -r nixos.zip .
```

## Post-Install

After flashing the device, ensure your device attains the ip address `172.16.42.1` from the DHCP server on the superbird. There is no SSH password, so you can connect by running `ssh root@172.16.42.2`.

## Known Issues

- there's a mouse cursor on the screen in weston when you use the wheel

<!-- ## Troubleshooting

On some desktop environments, Network Manager will try to set up the new USB network interface and randomly disconnect in the middle of operations. If this happens, run `nmcli device set <interface_name> managed no`. -->

<!-- ## Notes

To make the install easier, I committed the SSH keys that the devices will use. This is not a problem as the only way to connect to this device is via USB. You can configure custom keys in your `flake.nix` if you so choose.

I am new to Nix and hate Python with a passion, so code quality could probably use some work. PRs welcome! -->

## Prior Art

I would like to give a massive shoutout to [alexcaoys](https://github.com/alexcaoys). Their work on the [linux-superbird-6.6.y](https://github.com/alexcaoys/linux-superbird-6.6.y) kernel made this entire project possible.

I also must acknowledge the work [bishopdynamics](https://github.com/bishopdynamics) did on [superbird-tool](https://github.com/bishopdynamics/superbird-tool) and of course [frederic](https://github.com/frederic) for introducing Car Thing hacking to the world.
