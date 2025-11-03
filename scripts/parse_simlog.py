#!/usr/bin/env python3
# scripts/parse_simlog.py

"""
Parses a simulation log file to find UVM_ERROR lines, extracts hexadecimal
values from them, and prints their corresponding floating-point representations.
"""

import argparse
import re
import sys
from pathlib import Path

# Add project root to Python path to allow importing from 'verif'
project_root = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(project_root))


from verif.lib.fp16_model import parse_fp16_value


def process_log_file(log_path: Path) -> None:
    """
    Reads a log file, finds UVM_ERROR lines, and processes them.

    Args:
        log_path (Path): The path to the log file.
    """
    hex_pattern = re.compile(r"0x[0-9a-fA-F]+")
    found_error = False

    try:
        with log_path.open("r", encoding="utf-8", errors="ignore") as f:
            for line_num, line in enumerate(f, 1):
                if "UVM_ERROR" in line:
                    if not found_error:
                        print("-" * 80)
                    found_error = True

                    hex_values = hex_pattern.findall(line)
                    print(f"Found UVM_ERROR on line {line_num}:\n{line.strip()}")

                    if hex_values:
                        print("  Floating-point representations:")
                        for hex_val in set(hex_values):  # Use set to avoid duplicates
                            try:
                                float_val = parse_fp16_value(hex_val)
                                print(
                                    f"    {hex_val} -> {float_val:.7f} ({float_val:.7e})"
                                )
                            except (ValueError, TypeError):
                                print(f"    {hex_val} -> (Could not parse as fp16)")
                        print("-" * 80)

        if not found_error:
            print("No UVM_ERROR lines found in the log file.")

    except IOError as e:
        print(f"Error reading file {log_path}: {e}", file=sys.stderr)
        sys.exit(1)


def parse_args() -> argparse.Namespace:
    """
    Parse command line arguments.

    Returns:
        argparse.Namespace: Parsed command line arguments.
    """
    parser = argparse.ArgumentParser(
        description="Parse UVM log files for errors and print FP representations of hex values."
    )
    parser.add_argument("logfile", type=Path, help="Path to the log file to process.")
    return parser.parse_args()


def main() -> None:
    """Program entry point."""
    args = parse_args()
    if not args.logfile.is_file():
        print(f"Error: Log file not found at '{args.logfile}'", file=sys.stderr)
        sys.exit(1)

    process_log_file(args.logfile)


if __name__ == "__main__":
    main()
