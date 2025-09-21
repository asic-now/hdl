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
from typing import Dict, List
import fnmatch
import re

# Default mapping of file extensions to their single-line comment prefix.
# This can be overridden or extended via command-line arguments.
DEFAULT_COMMENT_MAP_CONFIG = [
    ".py,.sh:#",
    ".h,.c,.cpp,.hpp,.java,.js,.ts,.go,.rs://",
    ".v,.vh,.sv,.svh://",
]


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

    This function handles shebangs and Python docstrings, searching for a partial
    filename match in comments to replace, or inserting a new comment if no
    suitable one is found.

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
        filename_stem = file_path.stem

        with file_path.open("r", encoding="utf-8", errors="ignore") as f:
            lines = f.readlines()

        line_to_replace_idx = -1
        insertion_point = 0
        docstring_end_line = -1

        # 1. Handle shebang to adjust potential insertion point
        if lines and lines[0].startswith("#!"):
            insertion_point = 1

        # 2. Skip Python module-level docstrings and find the real insertion point
        if ext == ".py":
            docstring_start_idx = -1
            # Find start of module docstring (must have no indent)
            for i in range(insertion_point, len(lines)):
                line_strip = lines[i].strip()
                if line_strip:  # Find first non-empty line
                    # A module docstring cannot be indented.
                    if not lines[i].startswith((" ", "\t")) and line_strip.startswith(
                        ('"""', "'''")
                    ):
                        docstring_start_idx = i
                    break  # Stop after the first non-empty line regardless

            if docstring_start_idx != -1:
                quote_type = lines[docstring_start_idx].strip()[:3]
                # Check for single-line docstring
                if (
                    lines[docstring_start_idx].strip().endswith(quote_type)
                    and len(lines[docstring_start_idx].strip()) > 3
                ):
                    docstring_end_line = docstring_start_idx
                else:  # Search for end of multi-line docstring
                    for i in range(docstring_start_idx + 1, len(lines)):
                        if lines[i].strip().endswith(quote_type):
                            docstring_end_line = i
                            break

            if docstring_end_line != -1:
                insertion_point = docstring_end_line + 1

        # 3. Check for compliance or find a line to replace
        # Pattern to find a path-like string containing the filename stem.
        # This is more robust than a simple `filename in line` check.
        path_like_pattern = re.compile(
            rf"([a-zA-Z0-9/._-]*{re.escape(filename_stem)}[a-zA-Z0-9._-]*)"
        )

        for i, line in enumerate(lines):
            line_strip = line.strip()
            if line_strip == expected_line:
                return  # File is already compliant

            # A line is a candidate for replacement if it's a comment, not part of a docstring,
            # and contains a path-like reference to the current file.
            is_after_docstring = (
                ext != ".py" or docstring_end_line == -1 or i > docstring_end_line
            )
            if is_after_docstring and line_strip.startswith(comment_prefix):
                comment_content = line_strip[len(comment_prefix) :].strip()
                if (
                    path_like_pattern.search(comment_content)
                    and line_to_replace_idx == -1
                ):  # Found first potential match
                    line_to_replace_idx = i

        # 4. Decide what action to take, considering if the file was modified
        needs_action = False
        if line_to_replace_idx != -1:
            # Found a partial match to replace
            needs_action = True
            relative_path_str = file_path.relative_to(base_path).as_posix()
            if fix:
                print(
                    f"[FIXING] {relative_path_str} (replacing line {line_to_replace_idx + 1})"
                )
                lines[line_to_replace_idx] = f"{expected_line}\n"
            else:
                print(
                    f"[NEEDS FIX] {relative_path_str} (would replace line {line_to_replace_idx + 1})"
                )
        elif any(line.strip() for line in lines):  # Don't add header to empty files
            # No suitable match found, need to insert a new line
            needs_action = True
            relative_path_str = file_path.relative_to(base_path).as_posix()
            if fix:
                print(f"[FIXING] {relative_path_str} (inserting header)")
                lines.insert(insertion_point, f"{expected_line}\n")
            else:
                print(f"[NEEDS FIX] {relative_path_str} (would insert header)")

        # 5. Write changes if in fix mode and an action was identified
        if fix and needs_action:
            with file_path.open("w", encoding="utf-8") as f:
                f.writelines(lines)

    except (IOError, OSError) as e:
        print(f"Error processing file {file_path}: {e}", file=sys.stderr)
    except Exception as e:
        print(f"An unexpected error occurred with {file_path}: {e}", file=sys.stderr)


def build_ignore_list(
    base_path: Path, no_gitignore: bool, extra_excludes: List[str]
) -> List[str]:
    """
    Builds a list of gitignore-style patterns to ignore.

    This is a simplified implementation and does not support all features of
    .gitignore files, such as negation patterns (`!`).

    Args:
      base_path: The root directory of the scan.
      no_gitignore: If True, .gitignore files are not read.
      extra_excludes: A list of additional patterns to exclude.

    Returns:
      A list of glob patterns to be ignored.
    """
    # Start with user-provided exclude patterns
    ignore_patterns = [p.replace("\\", "/") for p in extra_excludes]

    if no_gitignore:
        return ignore_patterns

    # Search for all .gitignore files in the directory tree
    for gitignore_path in base_path.rglob(".gitignore"):
        try:
            with gitignore_path.open("r", encoding="utf-8", errors="ignore") as f:
                # The directory where the .gitignore file is located, relative to base_path
                gitignore_dir = gitignore_path.parent.relative_to(base_path)

                for line in f:
                    line = line.strip()
                    # Ignore comments and empty lines
                    if line and not line.startswith("#"):
                        # A pattern starting with '/' is anchored to the directory containing the .gitignore file.
                        # For simplicity, we make it relative to the root of the scan if it starts with a slash.
                        if line.startswith("/"):
                            pattern_path = line.lstrip("/")
                        else:
                            # Otherwise, it's relative to the .gitignore file's directory
                            pattern_path = gitignore_dir.joinpath(line).as_posix()

                        ignore_patterns.append(pattern_path)

        except (IOError, OSError) as e:
            print(f"Warning: Could not read {gitignore_path}: {e}", file=sys.stderr)

    return ignore_patterns


def is_path_ignored(path: Path, base_path: Path, ignore_patterns: List[str]) -> bool:
    """
    Checks if a path matches any of the ignore patterns.

    Args:
      path: The file or directory path to check.
      base_path: The root directory of the scan.
      ignore_patterns: A list of glob patterns to ignore.

    Returns:
      True if the path should be ignored, False otherwise.
    """
    if not path.is_relative_to(base_path):
        return False

    relative_path_str = path.relative_to(base_path).as_posix()

    for pattern in ignore_patterns:
        # Handle direct and glob matches (e.g., '*.log', 'file.txt')
        if fnmatch.fnmatch(relative_path_str, pattern):
            return True

        # Handle directory matches (e.g., 'node_modules' should match 'node_modules/file.js')
        dir_pattern = pattern.rstrip("/")
        if relative_path_str.startswith(dir_pattern + "/"):
            return True

    return False


def parse_args() -> argparse.Namespace:
    """
    Parses command-line arguments.

    Returns:
      A Namespace object containing the parsed arguments.
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
        "-r",
        "--recursive",
        action="store_true",
        help="Traverse directories recursively.",
    )

    parser.add_argument(
        "--no-gitignore",
        action="store_true",
        help="Do not read .gitignore files to exclude paths.",
    )

    parser.add_argument(
        "-e",
        "--exclude",
        dest="exclude",
        action="append",
        default=[],
        help="Additional path or pattern to exclude (e.g., 'node_modules' or '*.log'). Can be specified multiple times.",
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
    # Set default for map_config if it wasn't provided
    if not args.map_config:
        args.map_config = DEFAULT_COMMENT_MAP_CONFIG
    return args


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
        print(f"Recursive: {args.recursive}")

        ignore_patterns = build_ignore_list(base_path, args.no_gitignore, args.exclude)
        if ignore_patterns:
            print(f"Ignoring patterns: {ignore_patterns}")

        print("-" * 30)

        # Use rglob for recursive, glob for non-recursive
        iterator = base_path.rglob("*") if args.recursive else base_path.glob("*")

        for path in iterator:
            if is_path_ignored(path, base_path, ignore_patterns):
                continue

            if path.is_file():
                process_file(path, base_path, comment_map, args.fix)

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
