import sys
from superbird_device import SuperbirdDevice, find_device, enter_burn_mode

BOOTFS = "./bootfs.bin"
ROOTFS = "./rootfs.img"
ENVS = "./env.txt"

BOOT_RESTORE_BLOCK_OFFSET = 0
# ROOT_RESTORE_BLOCK_OFFSET = 319488
ROOT_RESTORE_BLOCK_OFFSET = 352256


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
    print("""


                ███╗   ██╗██╗██╗  ██╗ ██████╗ ███████╗
                ████╗  ██║██║╚██╗██╔╝██╔═══██╗██╔════╝
                ██╔██╗ ██║██║ ╚███╔╝ ██║   ██║███████╗
                ██║╚██╗██║██║ ██╔██╗ ██║   ██║╚════██║
                ██║ ╚████║██║██╔╝ ██╗╚██████╔╝███████║
                ╚═╝  ╚═══╝╚═╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝

███████╗██╗   ██╗██████╗ ███████╗██████╗ ██████╗ ██╗██████╗ ██████╗
██╔════╝██║   ██║██╔══██╗██╔════╝██╔══██╗██╔══██╗██║██╔══██╗██╔══██╗
███████╗██║   ██║██████╔╝█████╗  ██████╔╝██████╔╝██║██████╔╝██║  ██║
╚════██║██║   ██║██╔═══╝ ██╔══╝  ██╔══██╗██╔══██╗██║██╔══██╗██║  ██║
███████║╚██████╔╝██║     ███████╗██║  ██║██████╔╝██║██║  ██║██████╔╝
╚══════╝ ╚═════╝ ╚═╝     ╚══════╝╚═╝  ╚═╝╚═════╝ ╚═╝╚═╝  ╚═╝╚═════╝

""")

    print(
        "WARNING: this is a very destructive script. make sure you know what it is going to do!"
    )

    print("\n")
    print("please boot your device into usb mode")
    print(
        "this is done by by plugging it in while holding the 1st and 4th buttons on the top."
    )
    input("press enter when done >>> ")
    print("\n")

    device = get_device()
    device.bulkcmd("amlmmc key")

    print("this script will now overwrite the device's filesystems.")
    input("press enter when ready >>> ")
    print("\n")

    print(
        "this script will now write the boot filesystem to the device. this will take a second."
    )
    device.restore_partition(BOOT_RESTORE_BLOCK_OFFSET, BOOTFS)

    print(
        "this script will now write the root filesystem to the device. this will take a very long while."
    )
    device.restore_partition(ROOT_RESTORE_BLOCK_OFFSET, ROOTFS)

    print("this script will now write the env")
    device.send_env_file(ENVS)
    device.bulkcmd("saveenv")

    print("\n")
    print("done!\n")

    print(
        "you should now have a fully functioning NixOS install! power cycle and enjoy!"
    )
