# NixOS for the Spotify Car Thing

`nixos-superbird` is a project to help build custom Linux images for the Spotify Car Thing and easily install them. This is the first project (to my knowledge) to democratize Linux for the Superbird, and by far the easiest way to attain full control of the Car Thing.

This project was originally built in 24 hours for [Car Thang](https://github.com/BounceU/car_thang) during a hackathon.

**If you would like to support the development of `nixos-superbird` and Car Thang, please consider sending us any old Car Things you may have lying around. They are rather expensive now.**

## Features

- [x] fully customizable NixOS
- [x] one-click guided installer
- [x] compressed BTRFS filesystem for maximum storage
- [x] support for Bluetooth and Bluetooth PAN (tetherless Car Thing, anyone?)
- [x] networked initrd for debugging
- [x] support for live deployments without rebuilding (thanks nix!)

## Setup

To use `nixos-superbird`, you must have either Nix installed on your computer, or have a Docker container with Nix (working on adding one). If you are not on an `aarch64-linux` machine (most of you), then you also need to have QEMU binfmt set up. Look up how to set that up on your distro.

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
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixos-superbird.url = "github:joeyeamigh/nixos-superbird/main";
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
          modules = [
            nixos-superbird.nixosModules.superbird
            {
              superbird.gui.app = "${pkgs.cog}/bin/cog https://github.com/JoeyEamigh/nixos-superbird";
              system.stateVersion = "24.11";
            }
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

## Configuration

To make this flake as easy to use as possible, not many things are directly configurable at the moment. You can obviously override anything I have set with `lib.mkForce`. You can view all superbird configuration options in [`./modules/default.nix`](./modules/default.nix), and the defaults are listed below. If you would like to add more config options, feel free to PR with the config and an example.

```nix
{
  superbird = {
    bluetooth = {
      enable = true;
      name = "Superbird";
    };

    gui = {
      enable = true;
      app = null;
    };

    swap = {
      enable = true;
      size = 512;
    };

    qemu = false;
  };
}
```

## Installation

Once you have built an installer, it will be output to `./result`. Due to the way that `mkfs.btrfs` works, the generated `result/linux/rootfs.img` will most likely be ~3x larger than it needs to be. To compress the image for flashing, first you must copy the files to another directory (since nix symlinks), then run the `scripts/shrink-img.sh` script. A convenience script `installer` is also included in the example flake `Justfile` which does this automatically.

```sh
mkdir ./out
cp -r ./result/* ./out/

cd ./out
sudo ./scripts/shrink-img.sh
```

Once you have shrunk the image, you are ready to install! Enter your new `out` directory, and run `./install.sh`. This script will walk you through the install process.

For a fully scripted installer build, simply run `just run-installer`.

## Post-Install

After the system is installed and booted, you will have to set up a wired network connection (which the installer took care of the first time around). The script at `out/scripts/ssh.sh` will configure your network based on the network interface detected during the install. This may change if you switch the USB port superbird is plugged into, so you can always change the interface name in `out/ssh/interface.txt`.

## Known Issues

- display rotation is sometimes incorrect
- touchscreen calibration is sometimes incorrect
- there's a mouse cursor on the screen
- bluetooth firmware will not load during boot, requires restart of bluetooth daemon

## Troubleshooting

On some desktop environments, Network Manager will try to set up the new USB network interface and randomly disconnect in the middle of operations. If this happens, run `nmcli device set <interface_name> managed no`.

## Notes

To make the install easier, I committed the SSH keys that the devices will use. This is not a problem as the only way to connect to this device is via USB. You can configure custom keys in your `flake.nix` if you so choose.

I am new to Nix and hate Python with a passion, so code quality could probably use some work. PRs welcome!

## Prior Art

I would like to give a massive shoutout to [alexcaoys](https://github.com/alexcaoys). Their work on the [linux-superbird-6.6.y](https://github.com/alexcaoys/linux-superbird-6.6.y) kernel made this entire project possible.

I also must acknowledge the work [bishopdynamics](https://github.com/bishopdynamics) did on [superbird-tool](https://github.com/bishopdynamics/superbird-tool) and of course [frederic](https://github.com/frederic) for introducing Car Thing hacking to the world.
