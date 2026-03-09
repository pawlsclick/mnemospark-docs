#!/usr/bin/env python3
"""Create a text file of arbitrary size (in megabytes)."""
"""Usage:"""
"""python3 scripts/text-file-maker.py --size 10"""
"""python3 scripts/text-file-maker.py --size 100 --output big.txt"""


import argparse
import random
import string
import sys

BYTES_PER_MB = 1024 * 1024
CHUNK_SIZE = 64 * 1024  # 64 KB write buffer
LINE = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed non.\n"
# Printable ASCII for --random: high entropy, still valid text, compresses poorly
RANDOM_CHARS = string.ascii_letters + string.digits + string.punctuation + " \n\t"


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Create a text file of the given size in megabytes."
    )
    parser.add_argument(
        "--size",
        type=float,
        required=True,
        metavar="MB",
        help="Size of the output file in megabytes",
    )
    parser.add_argument(
        "--output",
        "-o",
        type=str,
        default="output.txt",
        metavar="PATH",
        help="Output file path (default: output.txt)",
    )
    parser.add_argument(
        "--random",
        "-r",
        action="store_true",
        help="Fill with random printable text (harder to compress than repeating text)",
    )
    args = parser.parse_args()

    if args.size <= 0:
        parser.error("--size must be greater than 0")

    target_bytes = int(args.size * BYTES_PER_MB)

    try:
        with open(args.output, "wb") as f:
            written = 0
            if args.random:
                while written < target_bytes:
                    n = min(CHUNK_SIZE, target_bytes - written)
                    chunk = "".join(random.choices(RANDOM_CHARS, k=n)).encode("utf-8")
                    f.write(chunk)
                    written += len(chunk)
            else:
                chunk_lines = max(1, CHUNK_SIZE // len(LINE))
                chunk = (LINE * chunk_lines).encode("utf-8")
                while written < target_bytes:
                    to_write = min(len(chunk), target_bytes - written)
                    f.write(chunk[:to_write])
                    written += to_write
    except OSError as e:
        print(f"Error writing {args.output}: {e}", file=sys.stderr)
        sys.exit(1)

    print(f"Created {args.output} ({written:,} bytes, {args.size} MB)")


if __name__ == "__main__":
    main()
