import os
import sys
import subprocess
import platform
from argparse import ArgumentParser
import time
from superbird_device import SuperbirdDevice, find_device, enter_burn_mode

from pyroute2 import NDB

# credits: based heavily on https://github.com/bishopdynamics/superbird-tool by bishopdynamics
# macos work done by Jordan @1.tb

KERNEL = "./linux/kernel"
INITRD = "./linux/initrd.img"
DTB = "./linux/meson-g12a-superbird.dtb"
ROOTFS = "./linux/rootfs.img"

RESTORE_BLOCK_OFFSET = 319488

ENV_FULL_CUSTOM = "./env/full_custom.txt"
ENV_INITRD_INSTALL = "./env/initrd_install.txt"
ENV_INITRD_NET = "./env/initrd_net.txt"
ENV_INITRD_NO_NET = "./env/initrd_no_net.txt"

interfaces: list[str] = []
HOST_IP_ADDR = "172.16.42.1/24"
HOST_NET_TIMEOUT = 30

DEVICE_IP_ADDR = "172.16.42.2"
DEVICE_NET_DELAY = 25
DEVICE_NET_TIMEOUT = 30


def get_network_interfaces_macos() -> list[str]:
    """Get list of network interfaces on macOS"""
    try:
        result = subprocess.run(
            ["networksetup", "-listallhardwareports"], capture_output=True, text=True
        )
        interfaces = []
        for line in result.stdout.split("\n"):
            if line.startswith("Device:"):
                interfaces.append(line.split(": ")[1])
        return interfaces
    except Exception as e:
        print(f"Error getting network interfaces: {e}")
        return []


def save_network_interfaces_macos():
    """Save current list of network interfaces"""
    global interfaces
    interfaces = get_network_interfaces_macos()


def find_new_network_interface_macos() -> str | None:
    """Find any new network interface that appears"""
    current_interfaces = get_network_interfaces_macos()
    new_interfaces = set(current_interfaces) - set(interfaces)
    return next(iter(new_interfaces)) if new_interfaces else None


def set_interface_up_macos(ifname: str):
    """Configure network interface on macOS with additional verification"""
    try:
        print(f"\nConfiguring interface {ifname}...")

        subprocess.run(["sudo", "ifconfig", ifname, "down"], check=False)
        subprocess.run(["sudo", "ifconfig", ifname, "0.0.0.0"], check=False)

        subprocess.run(["sudo", "route", "-n", "delete", "172.16.42.0/24"], check=False)

        time.sleep(2)

        subprocess.run(
            [
                "sudo",
                "ifconfig",
                ifname,
                HOST_IP_ADDR,
                "netmask",
                "255.255.255.0",
                "up",
            ],
            check=True,
        )
        print("Interface configured with IP and brought up")

        subprocess.run(
            ["sudo", "route", "-n", "add", "172.16.42.0/24", HOST_IP_ADDR], check=True
        )
        print("Route added")

        result = subprocess.run(["ifconfig", ifname], capture_output=True, text=True)
        print(f"\nInterface status:\n{result.stdout}")

        result = subprocess.run(["netstat", "-nr"], capture_output=True, text=True)
        print(f"\nRouting table:\n{result.stdout}")

        print("\nWaiting for device network to stabilize...")
        time.sleep(10)

        print("\nAttempting to ping device...")
        for i in range(10):
            print(f"Ping attempt {i+1}/10...")
            if (
                subprocess.run(
                    ["ping", "-c", "1", "-t", "2", DEVICE_IP_ADDR], capture_output=True
                ).returncode
                == 0
            ):
                print("Device is responding to ping!")
                return
            time.sleep(2)
        print("Warning: Device is not responding to ping, but continuing anyway...")

    except subprocess.CalledProcessError as e:
        print(f"Error configuring network interface: {e}")
        sys.exit(1)


def save_network_interfaces_linux():
    with NDB() as ndb:
        for interface in ndb.interfaces.dump():  # type: ignore
            interfaces.append(interface.ifname)


def find_new_network_interface_linux() -> str | None:
    with NDB() as ndb:
        for interface in ndb.interfaces.dump():  # type: ignore
            if interface.ifname not in interfaces:
                return interface.ifname


def set_interface_up_linux(ifname: str):
    with NDB() as ndb:
        with ndb.interfaces[ifname] as iface:  # type: ignore
            iface.add_ip(HOST_IP_ADDR).set("state", "up")


def wait_for_ssh(ip: str, timeout: int = 30):
    """Wait for SSH to become available"""
    print(f"\nWaiting for SSH on {ip} to become available...")
    start_time = time.time()
    while time.time() - start_time < timeout:
        try:
            result = subprocess.run(
                [
                    "ssh",
                    "-o",
                    "ConnectTimeout=1",
                    "-o",
                    "StrictHostKeyChecking=no",
                    f"root@{ip}",
                    "echo 'SSH test'",
                ],
                capture_output=True,
                text=True,
            )
            if result.returncode == 0:
                print("SSH connection successful!")
                return True
        except Exception:
            pass
        print(".", end="", flush=True)
        time.sleep(1)
    print("\nSSH connection timed out!")
    return False


def get_device() -> SuperbirdDevice:
    print("finding device...")
    device_status = find_device(silent=True)
    device = SuperbirdDevice()

    if device_status != "usb" and device_status != "usb-burn":
        print("device could not be found. please try again.")
        sys.exit(1)

    if device_status == "usb":
        print("entering usb burn mode:\n\n")
        device = enter_burn_mode(device)
        print("\n")

    if device is None:
        print("device could not be found. please try again.")
        sys.exit(1)

    print("device found!")
    return device


if __name__ == "__main__":
    host_system = platform.system()
    save_network_interfaces = (
        save_network_interfaces_linux
        if host_system == "Linux"
        else save_network_interfaces_macos
    )
    find_new_network_interface = (
        find_new_network_interface_linux
        if host_system == "Linux"
        else find_new_network_interface_macos
    )
    set_interface_up = (
        set_interface_up_linux if host_system == "Linux" else set_interface_up_macos
    )

    parser = ArgumentParser(
        prog="install.py",
        description="Install Car Thang to your Car Thing",
    )
    parser.add_argument(
        "--network",
        action="store_true",
        default=False,
        help="boot the initrd, enable networking, then open an ssh shell",
    )
    parser.add_argument(
        "-n",
        "--no-net",
        action="store_true",
        default=False,
        help="install Car Thang without using host bridge networking (slower) - defaults to true on non-Linux hosts",
    )
    parser.add_argument(
        "--no-firewall",
        action="store_true",
        default=False,
        help="skip creating the firewall rules to connect to Car Thing",
    )
    args = parser.parse_args()

    print("""
   _____          _____    _______ _    _          _   _  _____
  / ____|   /\\   |  __ \\  |__   __| |  | |   /\\   | \\ | |/ ____|
 | |       /  \\  | |__) |    | |  | |__| |  /  \\  |  \\| | |  __
 | |      / /\\ \\ |  _  /     | |  |  __  | / /\\ \\ | . ` | | |_ |
 | |____ / ____ \\| | \\ \\     | |  | |  | |/ ____ \\| |\\  | |__| |
  \\_____/_/    \\_\\_|  \\_\\    |_|  |_|  |_/_/    \\_\\_| \\_|\\_____|
\n""")

    print(
        "WARNING: this is a very destructive script. make sure you know what it is going to do!"
    )

    if host_system != "Linux" and host_system != "Darwin":
        print("this script only supports Linux and MacOS at the moment")
        sys.exit(1)

    print("\n")
    print("please boot your device into usb mode")
    print(
        "this is done by by plugging it in while holding the 1st and 4th buttons on the top."
    )
    input("press enter when done >>> ")
    print("\n")

    device = get_device()

    if not args.no_net:
        if not args.no_firewall:
            print("this script will now attempt to set up your firewall rules.")
            input("press enter to continue >>> ")

            print("setting up iptables rules...")
            if host_system == "Linux":
                if subprocess.call("scripts/iptables.sh") != 0:
                    print("something went wrong setting up the firewall rules.")
                    sys.exit(1)
            elif host_system == "Darwin":
                if subprocess.call("scripts/pfctl.sh") != 0:
                    print("something went wrong setting up the firewall rules.")
                    sys.exit(1)

        print("making note of current network interfaces...")
        save_network_interfaces()
        print(f"current network interfaces: {interfaces}\n")

    print("this script will now boot the device and run the installer.")
    input("press enter when ready >>> ")
    print("\n")

    print("booting into initrd...")
    env_file = ENV_INITRD_INSTALL
    if args.no_net:
        env_file = ENV_INITRD_NO_NET
    elif args.network:
        env_file = ENV_INITRD_NET

    device.boot(memory=False, env_file=env_file, kernel=KERNEL, initrd=INITRD, dtb=DTB)
    print("\n")

    if not args.no_net:
        print("waiting for device network interface to come online...")
        new_interface = find_new_network_interface()
        timeout = time.time() + HOST_NET_TIMEOUT

        while new_interface is None:
            if time.time() > timeout:
                print(
                    "failed to find new network interface - did the device actually boot?"
                )
                sys.exit(1)

            time.sleep(1)
            new_interface = find_new_network_interface()

        print("network interface found! setting interface up\n")
        set_interface_up(new_interface)
        with open("./ssh/interface.txt", "w") as iface_file:
            iface_file.write(new_interface)
        os.chown("./ssh/interface.txt", 1000, 1000)
        os.chmod("./ssh/interface.txt", 0o777)

    if args.network:
        print(f"allowing device some time to boot, please wait {DEVICE_NET_DELAY}s...")
        time.sleep(DEVICE_NET_DELAY)
        print("opening ssh connection...")
        subprocess.run(
            ["ssh", "-o", "StrictHostKeyChecking=no", f"root@{DEVICE_IP_ADDR}"]
        )
        sys.exit(0)

    print(
        "the installer will now run. please wait for a bit and watch the output on the display until it stops outputting new lines for a while"
    )
    input("press enter when device is ready >>> ")
    print("\n")

    if not args.no_net:
        print(
            "this script will now copy the root filesystem to the device over ssh. this will take a while."
        )
        print(f"Checking if rootfs exists at {ROOTFS}...")
        if not os.path.exists(ROOTFS):
            print(f"ERROR: Could not find rootfs at {ROOTFS}")
            sys.exit(1)

        print("\nWaiting for device to complete boot sequence...")
        time.sleep(DEVICE_NET_DELAY)

        if not wait_for_ssh(DEVICE_IP_ADDR):
            print("\nFalling back to USB method since SSH is unavailable...")
            args.no_net = True
        else:
            print("\nStarting rootfs copy via SSH...")
            dd_command = f"dd if={ROOTFS} bs=1M status=progress | ssh -o StrictHostKeyChecking=no root@{DEVICE_IP_ADDR} dd of=/dev/mmcblk2p2 bs=1M"
            print(f"Running command: {dd_command}")
            result = os.system(dd_command)

            if result != 0:
                print("\nERROR: SSH copy failed, falling back to USB method...")
                args.no_net = True
            else:
                print("\nSSH copy completed successfully!")

    if args.no_net:
        print("now you must boot your device into usb mode one more time")
        print(
            "unplug your device, then replug it while holding the 1st and 4th buttons on the top."
        )
        input("press enter when done >>> ")
        print("\n")

        device = get_device()
        print(
            "this script will now write the root filesystem to the device. this will take a very long while."
        )
        device.restore_partition(RESTORE_BLOCK_OFFSET, ROOTFS)
        print("\n")
        print("done!\n")
    else:
        print("now you must boot your device into usb mode one more time")
        print(
            "unplug your device, then replug it while holding the 1st and 4th buttons on the top."
        )
        input("press enter when done >>> ")
        print("\n")

        device = get_device()

    print("this script will now set the u-boot env vars for booting the new system.")
    device.bulkcmd("amlmmc env")
    print("sending full_custom env file...")
    device.send_env_file(ENV_FULL_CUSTOM)
    device.bulkcmd("env save")

    print("\n")
    print("done!\n")

    print("you should now have a fully functioning Car Thang! power cycle and enjoy!")
