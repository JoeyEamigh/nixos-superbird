#!/usr/bin/env python3
"""
Wrapper for performing tasks on superbird device
"""
# pylint: disable=line-too-long,broad-except

import os
import sys
import time
import traceback
import platform
from typing import Literal

try:
    from pyamlboot import pyamlboot
    from usb.core import USBTimeoutError, USBError
    import usb.core
except ImportError:
    print("""
    ###########################################################################################

    Error while importing pyamlboot!
    """)
    if platform.system() == "Darwin":
        print("""
        on macOS, you must install python3 and libusb from homebrew,
        and execute using that version of python
            brew install python3 libusb
            /opt/homebrew/bin/python3 -m pip install git+https://github.com/superna9999/pyamlboot
            /opt/homebrew/bin/python3 superbird_tool.py
        root is not needed on macOS
        """)
    elif platform.system() == "Linux":
        print("""
        on Linux, you just need to install pyamlboot
        root is needed on Linux, unless you fiddle with udev rules,
        which means the pip package also needs to be installed as root
            sudo python3 -m pip install git+https://github.com/superna9999/pyamlboot
            sudo ./superbird_tool.py
        """)
    else:
        print("""
        on Windows, you need to download and install python3 from https://www.python.org/downloads/windows/
        and execute using "python" instead of "python3"
            python -m pip install git+https://github.com/superna9999/pyamlboot
            python superbird_tool.py
        """)
    print("""
    You need to install pyamlboot from github because the current pypy package is too old

    ############################################################################################
    """)
    sys.exit(1)

# from superbird_partitions import SUPERBIRD_PARTITIONS

BURN_MODE_TIMEOUT = 10  # seconds, how long to wait for device to enter USB Burn Mode


class BulkcmdException(Exception):
    """
    So we can catch this specifically
    """


def find_device(
    silent: bool = False,
) -> Literal["normal", "usb-burn", "usb", "not-found"]:
    """Find a superbird device and return its mode
    modes: normal, usb, usb-burn
    """
    try:
        found_devices = usb.core.find(idVendor=0x18D1, idProduct=0x4E40)
        if found_devices is not None:
            dev_product = found_devices[0].device.product  # type: ignore
            if not silent:
                print(
                    "Found device booted normally, with USB Gadget (adb/usbnet) enabled"
                )
            return "normal"
        found_devices = usb.core.find(idVendor=0x1B8E, idProduct=0xC003)
        if found_devices is not None:
            dev_product = found_devices[0].device.product  # type: ignore
            if dev_product is None:
                if not silent:
                    print("Found device booted in USB Burn Mode (ready for commands)")
                return "usb-burn"
            elif dev_product == "GX-CHIP":
                if not silent:
                    print(
                        "Found device booted in USB Mode (buttons 1 & 4 held at boot)"
                    )
                return "usb"
        if not silent:
            print("No device found!")
    except Exception:
        if not silent:
            print("Found a potential device that is not ready")
    return "not-found"


def check_device_mode(mode: str, silent: bool = False):
    """confirm if device is in the mode we need"""
    dev_mode = find_device(silent=True)
    if dev_mode != mode:
        if not silent:
            print("Device is not booted to the correct mode!")
        if mode == "usb":
            if not silent:
                print(
                    "     need to power on while holding buttons 1 & 4 to enter USB Mode"
                )
        elif mode == "usb-burn":
            if not silent:
                print("     need to boot into USB Burn Mode")
        elif mode == "normal":
            if not silent:
                print("     need to boot up normally first")
        return False
    return True


def enter_burn_mode(dev, silent: bool = False):
    """check device mode and enter burn mode if needed
    returns a new device object, or None if failure
    """
    dev_mode = find_device(silent)
    if dev_mode == "usb-burn":
        return dev
    elif dev_mode == "usb":
        print("Entering USB Burn Mode")
        dev.bl2_boot(
            "boot/superbird.bl2.encrypted.bin", "boot/superbird.bootloader.img"
        )
        print("Waiting for device...")
        # wait for it to boot up in USB Burn Mode
        wait_time = 0
        while wait_time <= BURN_MODE_TIMEOUT:
            time.sleep(1)
            if check_device_mode("usb-burn", silent=True):
                break
            wait_time += 1
        if check_device_mode("usb-burn"):
            print("Device is now in USB Burn Mode")
            time.sleep(0.5)
            dev = SuperbirdDevice()
            time.sleep(1)
            dev.bulkcmd("amlmmc part 1")
            return dev
        else:
            print("Failed to enter USB Burn Mode!")
            return None
    else:
        print(f"Cannot enter burn mode from current mode: {dev_mode}")
        return None


def stdout_clear_lines(num: int = 1):
    """un-print the last N lines"""
    while num > 0:
        sys.stdout.write(
            "\x1b[1A\x1b[2K"
        )  # move cursor up one line, and delete that whole line
        num -= 1


class SuperbirdDevice:
    """convenience wrapper for superbird device"""

    ADDR_BL2 = 0xFFFA0000
    ADDR_KERNEL = 0x01080000
    ADDR_INITRD = 0x8840000
    ADDR_DTB = 0x01000000
    ADDR_TMP = 0x13000000
    # commands which cause a usb timeout when reading response
    #   for any other commands, we raise an exception if they cause a timeout
    TIMEOUT_COMMANDS = ["booti", "bootm", "bootp", "mw.b", "reset", "reboot"]
    # PARTITIONS = SUPERBIRD_PARTITIONS
    PART_SECTOR_SIZE = 512  # bytes, size of sectors used in partition table
    TRANSFER_BLOCK_SIZE = (
        8 * PART_SECTOR_SIZE
    )  # 4KB data transfered into memory one block at a time
    WRITE_CHUNK_SIZE = (
        1024 * PART_SECTOR_SIZE
    )  # 512KB chunk written to memory, then gets written to mmc
    READ_CHUNK_SIZE = (
        256 * PART_SECTOR_SIZE
    )  # 128KB chunk read from mmc into memory, then read out to local file
    # writes larger than threshold will be broken into chunks of WRITE_CHUNK_SIZE
    TRANSFER_SIZE_THRESHOLD = 2 * 1024 * 1024  # 2MB

    def __init__(self) -> None:
        try:
            self.device = pyamlboot.AmlogicSoC()
        except ValueError:
            print("Device not found, is it in usb burn mode?")
            sys.exit(1)
        except USBError as exu:
            if exu.errno == 13:
                # [Errno 13] Access denied (insufficient permissions)
                print(f"{exu}, need to run as root")
                sys.exit(1)
            else:
                print(f"Error: {exu}")
                print(traceback.format_exc())
                sys.exit(1)
        else:
            if not hasattr(self.device, "bulkCmd"):
                self.print(
                    "Detected an old version of pyamlboot which lacks AmlogicSoC.bulkCmd"
                )
                self.print("Need to install from the github master branch")
                self.print(
                    " need to uninstall the current version, then install from github"
                )
                self.print("  python3 -m pip uninstall pyamlboot")
                self.print(
                    "  python3 -m pip install git+https://github.com/superna9999/pyamlboot"
                )
                sys.exit(1)

    @staticmethod
    def decode(response):
        """decode a response"""
        return response.tobytes().decode("utf-8")

    @staticmethod
    def print(message: str):
        """print a message to console
        on Windows, need to flush after printing
        or nothing will show up until script is complete
        """
        print(message)
        sys.stdout.flush()

    def bulkcmd(self, command: str, ignore_timeout=False, silent=False):
        """perform a bulkcmd, separated by semicolon"""
        if not silent:
            self.print(f' executing bulkcmd: "{command}"')
        try:
            resp = self.device.bulkCmd(command)
            response = self.decode(resp)
            if not silent:
                self.print(f"  result: {response}")
            if "success" not in response:
                self.print(f"Bulkcmd failed: {command} -> {response}")
                raise BulkcmdException("Bulkcmd failed")
            time.sleep(0.2)
        except (USBTimeoutError, BulkcmdException) as ex:
            # if you use booti or mw.b, it wont return, thus will raise USBTimeoutError
            if [
                word for word in self.TIMEOUT_COMMANDS if word in command
            ] or ignore_timeout:
                if not silent:
                    self.print("  ...")
            else:
                self.print(
                    f" Error ({ex.__class__.__name__}): bulkcmd timed out or failed!"
                )
                self.print(
                    " This can happen if the device ends up in a strange state, like as the result of a previously failed command"
                )
                self.print(
                    " Try power cycling the device by pulling the cable, and then boot up and try again"
                )
                self.print("  You might need to do this multiple times")
                self.print(
                    "    If the device is connected through a USB hub, try connecting it directly to a port on your machine"
                )
                sys.exit(1)
        except USBError:
            # on Windows, raises USBError instead of USBTimeoutError
            if [
                word for word in self.TIMEOUT_COMMANDS if word in command
            ] or ignore_timeout:
                if not silent:
                    self.print("  ...")
            else:
                self.print(" Error: bulkcmd timed out!")
                self.print(
                    " This can happen if the device ends up in a strange state, like as the result of a previously failed command"
                )
                self.print(
                    " Try power cycling the device by pulling the cable, and then boot up and try again"
                )
                self.print("  You might need to do this multiple times")
                self.print(
                    "    If the device is connected through a USB hub, try connecting it directly to a port on your machine"
                )
                sys.exit(1)

    def write(self, address: int, data, chunk_size=8, append_zeros=True):
        """write data to an address"""
        self.print(f" writing to: {hex(address)}")
        self.device.writeLargeMemory(address, data, chunk_size, append_zeros)

    def send_env(self, env_string: str):
        """send given env string to device, space-separated kernel args on one line"""
        env_size = len(env_string.encode("ascii"))
        self.print("initializing env subsystem")
        self.bulkcmd("amlmmc env")  # initialize env subsystem
        self.print(f"sending env ({env_size} bytes)")
        self.write(
            self.ADDR_TMP, env_string.encode("ascii")
        )  # write env string somewhere
        self.bulkcmd(
            f"env import -t {hex(self.ADDR_TMP)} {hex(env_size)}"
        )  # read env from string

    def send_env_file(self, env_file: str):
        """read env.txt, then send it to device"""
        env_data = ""
        with open(env_file, "r", encoding="utf-8") as envf:
            env_data = envf.read()
        self.send_env(env_data)

    def send_file(
        self, filepath: str, address: int, chunk_size: int = 512, append_zeros=True
    ):
        """write given file to device memory at given address"""
        self.print(f"writing {filepath} at {hex(address)}")
        file_data = None
        with open(filepath, "rb") as flp:
            file_data = flp.read()
        self.write(address, file_data, chunk_size, append_zeros)

    def bl2_boot(self, bl2_file: str, bootloader_file: str):
        """send a bl2 and then chain a uboot image with it"""
        # TODO there is something wrong with bl2_boot
        self.send_file(bl2_file, self.ADDR_BL2, chunk_size=4096, append_zeros=True)
        self.device.run(self.ADDR_BL2)
        data = None
        with open(bootloader_file, "rb") as blf:
            data = blf.read()
        time.sleep(2)

        prev_length = -1
        prev_offset = -1
        seq = 0
        while True:
            (length, offset) = self.device.getBootAMLC()

            if length == prev_length and offset == prev_offset:
                self.print("[BL2 END]")
                break

            prev_length = length
            prev_offset = offset

            self.print(f"AMLC dataSize={length}, offset={offset}, seq={seq}")
            self.device.writeAMLCData(seq, offset, data[offset : offset + length])
            self.print("[DONE]")

            seq = seq + 1

    # taken from https://github.com/alexcaoys/notes-superbird
    def boot(self, memory: bool, env_file: str, kernel="", initrd="", dtb=""):
        """boot using given env.txt, kernel, dtb and initrd"""
        self.send_env_file(env_file)
        if memory:
            print(
                f"Booting from memory {env_file=}, {self.ADDR_KERNEL=}, {self.ADDR_INITRD=}, {self.ADDR_DTB=}"
            )
            cmd = f"booti {hex(self.ADDR_KERNEL)}"
            if initrd:
                cmd += f" {hex(self.ADDR_INITRD)}"
            if dtb:
                if not initrd:
                    cmd += " -"
                cmd += f" {hex(self.ADDR_DTB)}"
        else:
            print(f"Booting {env_file=}, {kernel=}, {initrd=}, {dtb=}")
            self.send_file(kernel, self.ADDR_KERNEL)
            cmd = f"booti {hex(self.ADDR_KERNEL)}"
            if initrd:
                self.send_file(initrd, self.ADDR_INITRD)
                cmd += f" {hex(self.ADDR_INITRD)}"
            if dtb:
                self.send_file(dtb, self.ADDR_DTB)
                if not initrd:
                    cmd += " -"
                cmd += f" {hex(self.ADDR_DTB)}"
        try:
            self.bulkcmd(cmd)
        except Exception as e:
            print(e)

    def read_memory(self, address, length):
        """Read some data from memory"""
        data = None
        offset = 0
        while length:
            if length >= 64:
                read_data = self.device.readSimpleMemory(address + offset, 64).tobytes()  # type: ignore
                if data is not None:
                    data = data + read_data
                else:
                    data = read_data
                length = length - 64
                offset = offset + 64
            else:
                read_data = self.device.readSimpleMemory(
                    address + offset, length
                ).tobytes()  # type: ignore
                if data is not None:
                    data = data + read_data
                else:
                    data = read_data
                break
        return data

    def restore_partition(self, part_offset: int, infile: str):
        """Restore given partition from given dump
        Like with dump_partition, we first have to read it into RAM, then instruct the device to write it to mmc, one chunk at a time
        """
        if part_offset < 319488:
            print("WARNING: You might be writing to reserved partitions!!!")
        input(
            f"Press any key to confirm: write {infile} to mmc offset {hex(part_offset)}"
        )
        self.bulkcmd("amlmmc part 1")
        try:
            chunk_size_sector = self.WRITE_CHUNK_SIZE
            chunk_size = self.WRITE_CHUNK_SIZE * self.PART_SECTOR_SIZE
            file_size = os.path.getsize(infile)
            with open(infile, "rb") as ifl:
                # now we are ready to actually write to the partition
                offset = 0
                last_chunk = False
                remaining = file_size

                while remaining:
                    if remaining <= chunk_size:
                        # chunk_size = remaining
                        last_chunk = True
                    progress = round((offset * 512 / file_size) * 100)
                    data = ifl.read(chunk_size)
                    remaining -= chunk_size
                    print(
                        f"writing to emmc: {hex(part_offset)}+{hex(offset)} from file: {infile}"
                    )
                    print(
                        f"progress: {progress}% remaining: {round(remaining / 1024 / 1024)}MB / {round(file_size / 1024 / 1024)}MB, chunk_size: {chunk_size / 1024}KB"
                    )
                    self.device.writeLargeMemory(
                        self.ADDR_TMP, data, self.TRANSFER_BLOCK_SIZE, appendZeros=True
                    )
                    self.bulkcmd(
                        f"amlmmc write 1 {hex(self.ADDR_TMP)} {hex(part_offset+offset)} {hex(chunk_size_sector)}"
                    )
                    offset += chunk_size_sector
                    if last_chunk:
                        break
        except Exception as e:
            # in the event of any failure while writing partitions,
            #   force the entire script to exit to prevent further possible damage
            print(f"Error while restoring partition {e}")
            print(traceback.format_exc())
            sys.exit(1)
