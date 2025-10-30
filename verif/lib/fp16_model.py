#!/usr/bin/env python3

"""
This script models 16-bit IEEE 754 half-precision operations.


E.g. "add" command adds two values given as hex (like 0xc540) with a given rounding mode
and outputs the result in multiple formats.
"""
# verif/lib/fp16_model.py

import argparse
from typing import Dict, List, Tuple

import numpy as np

# Rounding modes matching grs_round.vh
RNE = 0  # Round to Nearest, Ties to Even
RTZ = 1  # Round Towards Zero
RPI = 2  # Round Towards Positive Infinity
RNI = 3  # Round Towards Negative Infinity
RNA = 4  # Round to Nearest, Ties Away from Zero

ROUNDING_MODES = {"rne": RNE, "rtz": RTZ, "rpi": RPI, "rni": RNI, "rna": RNA}


def fp16_parse_hex(hex_str: str) -> np.float16:
    """Convert hexadecimal string to 2-byte big-endian fp16 value."""
    a_bytes = int(hex_str, 16).to_bytes(2, 'little')
    a = np.frombuffer(a_bytes, dtype=np.float16)[0]
    return a

def fp16_to_hex(fp16_val: np.float16) -> str:
    """Convert fp16 value to 2-byte big-endian hexadecimal string."""
    # c_bytes = np.array([fp16_val], dtype=np.float16).tobytes()
    c_bytes = fp16_val.tobytes()
    c_int = int.from_bytes(c_bytes, 'little')
    return f'{c_int:04x}'

def fp16_result(c) -> Dict[str, str]:
    """Convert result to hex, binary, decimal, octal."""
    c_bytes = c.tobytes()
    c_int = int.from_bytes(c_bytes, 'little')
    return {
        'fp16': str(c),
        'hex': f'{c_int:04x}',
        'bin': f'{c_int:016b}',
        'dec': str(c_int),
        'oct': f'{c_int:06o}',
    }

def round_float32_to_float16(val: np.float32, mode: int) -> np.float16:
    """
    Rounds a float32 value to float16 with a specified rounding mode.
    This is a simplified implementation. For full compliance, a more
    detailed bit-level manipulation is needed, especially for denormals.
    """
    if mode == RNE:  # Round to Nearest, Ties to Even (numpy default)
        return np.float16(val)

    # For other modes, we can use some tricks with higher precision floats
    # This is not perfect but works for many cases.
    # A proper implementation would involve bit-level manipulation of the float.
    if np.isinf(val) or np.isnan(val) or val == 0:
        return np.float16(val)

    if mode == RTZ:  # Round Towards Zero
        return (
            np.float16(np.trunc(val * (2**10)) / (2**10))
            if val > 0
            else np.float16(np.ceil(val * (2**10)) / (2**10))
        )
    if mode == RPI:  # Round Towards Positive Infinity
        return np.float16(np.ceil(val * (2**10)) / (2**10))
    if mode == RNI:  # Round Towards Negative Infinity
        return np.float16(np.floor(val * (2**10)) / (2**10))
    if mode == RNA:  # Round to Nearest, Ties Away from Zero
        # This is tricky without bit manipulation. Python's round() does this.
        # We'll do a simplified version.
        return np.float16(np.round(val, 4))  # Approximate

    # Default to RNE if mode is unknown
    return np.float16(val)


def fp16_add(a_hex: str, b_hex: str, rounding_mode: int = RNE) -> Dict[str, str]:
    """
    Add two IEEE 754 binary16 (fp16) numbers given as hex strings.

    Parameters:
        a_hex (str): First 16-bit half-precision floating-point value as a hex string (e.g. 'c540').
        b_hex (str): Second 16-bit half-precision floating-point value as a hex string.
        rounding_mode (int): The rounding mode to use, matching grs_round.vh.

    Returns:
        Dict[str, str]: Result in multiple formats (fp16 string, hex, bin, dec, oct).
    """

    # Convert hex strings to fp16
    a_fp16 = fp16_parse_hex(a_hex)
    b_fp16 = fp16_parse_hex(b_hex)

    # Perform operation in higher precision (float32) to have bits for rounding
    result_f32 = np.float32(a_fp16) + np.float32(b_fp16)

    # Round the result to fp16 using the specified mode
    c = round_float32_to_float16(result_f32, rounding_mode)

    print(f"DEBUG: a = {a_fp16}, b = {b_fp16}, c = {c}")
    return fp16_result(c)

def fp16_mul(a_hex: str, b_hex: str, rounding_mode: int = RNE) -> Dict[str, str]:
    """
    Multiply two IEEE 754 binary16 (fp16) numbers given as hex strings.

    Parameters:
        a_hex (str): First 16-bit half-precision floating-point value as a hex string.
        b_hex (str): Second 16-bit half-precision floating-point value as a hex string.
        rounding_mode (int): The rounding mode to use, matching grs_round.vh.

    Returns:
        Dict[str, str]: Result in multiple formats (fp16 string, hex, bin, dec, oct).
    """

    # Convert hex strings to fp16
    a_fp16 = fp16_parse_hex(a_hex)
    b_fp16 = fp16_parse_hex(b_hex)
    # Perform operation in higher precision (float32)
    result_f32 = np.float32(a_fp16) * np.float32(b_fp16)
    # Round the result to fp16 using the specified mode
    c = round_float32_to_float16(result_f32, rounding_mode)
    return fp16_result(c)

def fp16_print(numbers: List[str]) -> None:
    """
    Print IEEE 754 binary16 (fp16) numbers in float/scientific format.

    Accepts numbers in hex, bin, dec, or octal format.

    Parameters:
        numbers (List[str]): List of fp16 numbers as string in any format.

    Prints:
        Each number in float and scientific (exponential) notation.
    """
    for num_str in numbers:
        val = parse_fp16_value(num_str)
        # Print as float and scientific
        print(f"{num_str} -> {val:.7f}\t{val:.7e}")

def parse_args() -> argparse.Namespace:
    """
    Parse command line arguments for operation and operands.

    Returns:
        argparse.Namespace: Parsed command line arguments.
    """
    parser = argparse.ArgumentParser(
        description="Half-precision (fp16) CLI adder, multiplier, printer"
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    for cmd in ['add', 'mul']:
        sp = subparsers.add_parser(cmd, help=f"{cmd} two fp16 values")
        sp.add_argument("a", help="First operand (e.g. 0xc540, 50560, 0b1100... or 0o...)")
        sp.add_argument("b", help="Second operand (same format as first)")
        sp.add_argument(
            "--round",
            choices=ROUNDING_MODES.keys(),
            default="rne",
            help="Rounding mode",
        )
    sp = subparsers.add_parser('print', help="Print fp16 numbers as float/scientific")
    sp.add_argument("numbers", nargs='+',
        help="One or more fp16 bit-patterns (hex/bin/dec/oct) to print as float/scientific"
    )

    return parser.parse_args()

def detect_format(arg: str) -> Tuple[str, str]:
    """
    Detect the integer format (hex, bin, dec, oct) of an argument.

    Parameters:
        arg (str): Operand string.

    Returns:
        str: Format name ('hex', 'bin', 'dec', 'oct').
        str: prefix of the detected format.
    """
    if arg.lower().startswith("0x"):
        return 'hex', '0x'
    if arg.lower().startswith("0b"):
        return 'bin', '0b'
    if arg.lower().startswith("0o"):
        return 'oct', '0o'
    return 'dec', ''

def to_hex_str(arg: str) -> str:
    """
    Convert argument to canonical hex string (without markup).

    Parameters:
        arg (str): Operand string (any supported format).

    Returns:
        str: Hex string (e.g. 'c540').
    """
    if arg.lower().startswith("0x"):
        val = int(arg, 16)
    elif arg.lower().startswith("0b"):
        val = int(arg, 2)
    elif arg.lower().startswith("0o"):
        val = int(arg, 8)
    else:
        val = int(arg, 10)
    return f'{val:04x}'

def parse_fp16_value(arg: str) -> float:
    """
    Parse any supported fp16 bit-pattern format and return its float value.

    Parameters:
        arg (str): String representing fp16 bit pattern (hex/bin/dec/oct).

    Returns:
        float: The corresponding IEEE 754 half-precision float value.
    """
    hex_str = to_hex_str(arg)
    bytes_val = int(hex_str, 16).to_bytes(2, 'little')
    float_val = np.frombuffer(bytes_val, dtype=np.float16)[0]
    return float(float_val)

def main() -> None:
    """
    Program entry point. Parses arguments and prints result in matching format.
    """
    args = parse_args()
    if args.command in ("add", "mul"):
        fmt, prefix = detect_format(args.a)
        a_hex = to_hex_str(args.a)
        b_hex = to_hex_str(args.b)
        rounding_mode = ROUNDING_MODES[args.round]
        if args.command == "add":
            result = fp16_add(a_hex, b_hex, rounding_mode)
        else:
            result = fp16_mul(a_hex, b_hex, rounding_mode)
        # Only print result in matching format, with no markup
        print(prefix+result[fmt])
    elif args.command == "print":
        fp16_print(args.numbers)
    else:
        raise ValueError(f"Invalid command {args.command}")

if __name__ == "__main__":
    main()
