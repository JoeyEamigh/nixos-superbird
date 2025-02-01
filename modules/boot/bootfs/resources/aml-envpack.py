#!/usr/bin/env python3

import argparse

HEADER = bytes([0xFE, 0xA1, 0x1C, 0x10])
SEPARATOR = bytes([0x00])
PART_SIZE = 8 * 1024 * 1024  # 8 MiB


def sort_lines(lines):
    # Sort lines alphabetically with all capital letters before any lowercase letters
    return sorted(lines, key=lambda s: (s[0].islower(), s))


def pack_env(input_file, output_file, pad):
    with open(input_file, "r") as f:
        lines = f.readlines()

    lines = sort_lines(lines)

    binary_data = bytearray(HEADER)

    for line in lines:
        line = line.strip()
        if line and not line.startswith("#"):
            binary_data.extend(line.encode("utf-8"))
            binary_data.extend(SEPARATOR)

    # Pad the binary data to 8 MiB if padding is enabled
    if pad:
        if len(binary_data) < PART_SIZE:
            binary_data.extend([0x00] * (PART_SIZE - len(binary_data)))
        elif len(binary_data) > PART_SIZE:
            raise ValueError("Binary data exceeds 8 MiB limit")

    with open(output_file, "wb") as f:
        f.write(binary_data)


def transform_env(input_file, output_file):
    with open(input_file, "r") as f:
        lines = f.readlines()

    lines = sort_lines(lines)

    with open(output_file, "w") as f:
        for line in lines:
            line = line.strip()
            if line and not line.startswith("#"):
                f.write(line + "\n")


def main():
    parser = argparse.ArgumentParser(
        description="Pack a text file into a custom binary format."
    )
    parser.add_argument("input_file", help="The input text file to be packed.")
    parser.add_argument(
        "-o",
        "--output",
        default="env.bin",
        help="The output binary file name (default: env.bin).",
    )
    parser.add_argument(
        "--no-pad",
        action="store_true",
        help="Disable padding the binary data to 8 MiB.",
    )
    parser.add_argument(
        "-t",
        "--transform",
        action="store_true",
        help="Sort the input file and output a text file instead of a binary file.",
    )

    args = parser.parse_args()

    if args.transform:
        transform_env(args.input_file, args.output)
    else:
        pack_env(args.input_file, args.output, not args.no_pad)


if __name__ == "__main__":
    main()
