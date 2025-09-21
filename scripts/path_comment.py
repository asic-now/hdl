#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
A command-line tool to traverse a folder and ensure that files have a
comment line at the top containing their relative path.

The script can run in two modes:
1. --dryrun: Lists the files that are not compliant without modifying them.
2. --fix: Modifies non-compliant files to add the required header comment.

The script uses a configurable mapping of file extensions to comment styles.
"""

import argparse
import sys
from pathlib import Path
from typing import Dict, List, NamedTuple

# Default mapping of file extensions to their single-line comment prefix.
# This can be overridden or extended via command-line arguments.
DEFAULT_COMMENT_MAP_CONFIG = [
    ".py,.sh:#",
    ".h,.c,.cpp,.hpp,.java,.js,.ts,.go,.rs://",
    ".v,.vh,.sv,.svh://",
]


class ParsedArgs(NamedTuple):
    """A structure to hold the parsed command-line arguments."""

    folder: Path
    dry_run: bool
    fix: bool
    map_config: List[str]


def parse_comment_map(map_config: List[str]) -> Dict[str, str]:
    """
    Parses the command-line map configuration into a dictionary.

    Args:
      map_config: A list of strings, e.g., ['.h,.c://', '.py:#'].

    Returns:
      A dictionary mapping each extension to its comment prefix.
    """
    comment_map: Dict[str, str] = {}
    for item in map_config:
        parts = item.split(":", 1)
        if len(parts) != 2:
            raise ValueError(
                f"Invalid map format: '{item}'. Expected '.ext1,.ext2:comment'."
            )

        extensions_str, comment_prefix = parts
        if not comment_prefix:
            raise ValueError(f"Empty comment prefix for extensions '{extensions_str}'.")

        extensions = extensions_str.split(",")
        for ext in extensions:
            if ext:
                comment_map[ext] = comment_prefix
    return comment_map


def process_file(
    file_path: Path, base_path: Path, comment_map: Dict[str, str], fix: bool
) -> None:
    """
    Processes a single file to check for or add the path comment.

    Args:
      file_path: The absolute path to the file to process.
      base_path: The absolute path of the root directory for traversal.
      comment_map: A dictionary mapping file extensions to comment prefixes.
      fix: A boolean indicating whether to fix the file or just report.
    """
    ext = file_path.suffix
    if not ext or ext not in comment_map:
        return

    try:
        relative_path = file_path.relative_to(base_path).as_posix()
        comment_prefix = comment_map[ext]
        expected_line = f"{comment_prefix} {relative_path}"

        with file_path.open("r", encoding="utf-8", errors="ignore") as f:
            first_line = f.readline().strip()

        if first_line == expected_line:
            return  # File is already compliant

        # File is not compliant, decide action based on mode
        if fix:
            print(f"[FIXING] {relative_path}")
            with file_path.open("r", encoding="utf-8", errors="ignore") as f:
                lines = f.readlines()

            # If the first line is an old, incorrect comment, replace it. Otherwise, insert.
            if lines and lines[0].strip().startswith(comment_prefix):
                lines[0] = f"{expected_line}\n"
            else:
                lines.insert(0, f"{expected_line}\n")

            with file_path.open("w", encoding="utf-8") as f:
                f.writelines(lines)
        else:  # Dry run
            print(f"[NEEDS FIX] {relative_path}")

    except (IOError, OSError) as e:
        print(f"Error processing file {file_path}: {e}", file=sys.stderr)
    except Exception as e:
        print(f"An unexpected error occurred with {file_path}: {e}", file=sys.stderr)


def parse_args() -> ParsedArgs:
    """
    Parses command-line arguments.

    Returns:
      A NamedTuple containing the parsed arguments.
    """
    parser = argparse.ArgumentParser(
        description="Check and fix files to ensure they have a relative path comment.",
        formatter_class=argparse.RawTextHelpFormatter,
    )
    parser.add_argument("folder", type=Path, help="The root folder to traverse.")

    mode_group = parser.add_mutually_exclusive_group(required=True)
    mode_group.add_argument(
        "--dryrun",
        dest="dry_run",
        action="store_true",
        help="List files that need fixing without making any changes.",
    )
    mode_group.add_argument(
        "--fix",
        action="store_true",
        help="Modify non-compliant files to add the correct header.",
    )

    parser.add_argument(
        "--map",
        dest="map_config",
        action="append",
        help=(
            "Define a custom extension-to-comment mapping.\n"
            "Format: '.ext1,.ext2:comment_prefix'\n"
            "Example: --map '.c,.h://' --map '.py:#'\n"
            "Can be specified multiple times. Defaults will be used if not provided."
        ),
    )

    args = parser.parse_args()
    return ParsedArgs(
        folder=args.folder,
        dry_run=args.dry_run,
        fix=args.fix,
        map_config=args.map_config or DEFAULT_COMMENT_MAP_CONFIG,
    )


def main() -> int:
    """
    The main entry point for the script.
    """
    try:
        args = parse_args()

        if not args.folder.is_dir():
            print(
                f"Error: Provided path '{args.folder}' is not a directory.",
                file=sys.stderr,
            )
            return 1

        comment_map = parse_comment_map(args.map_config)
        base_path = args.folder.resolve()

        print(f"Starting scan in '{base_path}'...")
        print(f"Mode: {'Dry Run' if args.dry_run else 'Fix'}")
        print("-" * 30)

        # Use rglob to recursively find all files
        for file_path in base_path.rglob("*"):
            if file_path.is_file():
                process_file(file_path, base_path, comment_map, args.fix)

        print("-" * 30)
        print("Scan complete.")
        return 0

    except ValueError as e:
        print(f"Configuration Error: {e}", file=sys.stderr)
        return 1
    except Exception as e:
        print(f"An unexpected error occurred: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
