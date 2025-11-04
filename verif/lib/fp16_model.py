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
    a_bytes = int(hex_str, 16).to_bytes(2, "little")
    a = np.frombuffer(a_bytes, dtype=np.float16)[0]
    return a


def fp16_to_hex(fp16_val: np.float16) -> str:
    """Convert fp16 value to 2-byte big-endian hexadecimal string."""
    # c_bytes = np.array([fp16_val], dtype=np.float16).tobytes()
    c_bytes = fp16_val.tobytes()
    c_int = int.from_bytes(c_bytes, "little")
    return f"{c_int:04x}"


def fp16_result(c) -> Dict[str, str]:
    """Convert result to hex, binary, decimal, octal."""
    c_bytes = c.tobytes()
    c_int = int.from_bytes(c_bytes, "little")
    return {
        "fp16": str(c),
        "hex": f"{c_int:04x}",
        "bin": f"{c_int:016b}",
        "dec": str(c_int),
        "oct": f"{c_int:06o}",
    }


def round_fp32_to_fp16(val: np.float32, rm: int) -> np.float16:
    """
    Rounds a float32 value to float16 with a specified rounding mode,
    using bit-accurate logic per IEEE 754.
    """
    f32_bytes = val.tobytes()
    x = int.from_bytes(f32_bytes, "little")

    sign_bit = (x >> 16) & 0x8000
    exp_32 = (x >> 23) & 0xFF
    mant_32 = x & 0x7FFFFF

    if exp_32 == 0xFF:  # NaN or Infinity
        mant_16 = 0x0200 if mant_32 != 0 else 0
        result_int = sign_bit | 0x7C00 | mant_16
    else:
        exp_16 = exp_32 - 127 + 15

        if exp_16 >= 0x1F:  # Overflow
            if rm == RNI:
                result_int = 0xFBFF  # Max normal neg number
            elif rm == RTZ and sign_bit:
                result_int = 0xFBFF  # Max normal neg number
            else:
                result_int = sign_bit | 0x7C00  # Infinity
        elif exp_16 <= 0:  # Underflow to denormalized or zero
            if exp_16 < -10:  # Result is too small, flush to zero
                if rm == RPI and not sign_bit:
                    result_int = 0x0001  # Smallest denormal
                elif rm == RNI and sign_bit:
                    result_int = 0x8001  # Smallest denormal
                else:
                    result_int = sign_bit
            else:
                # Create denormalized value
                mant = (mant_32 | 0x800000) >> (1 - exp_16)
                lsb = mant & 0x2000
                g = mant & 0x1000
                # r = mant & 0x0800
                sticky = (mant & 0x0FFF) != 0
                mant_16 = mant >> 13

                if (
                    (rm == RNE and g and (sticky or lsb))
                    or (rm == RNA and g)
                    or (rm == RPI and not sign_bit and (g or sticky))
                    or (rm == RNI and sign_bit and (g or sticky))
                ):
                    mant_16 += 1
                result_int = sign_bit | mant_16
        else:
            # Normalized number
            lsb = mant_32 & 0x2000
            g = mant_32 & 0x1000
            # r = mant_32 & 0x0800
            sticky = (mant_32 & 0x0FFF) != 0
            mant_16 = mant_32 >> 13

            round_up = False
            if rm == RNE:  # Round to Nearest, Ties to Even
                if g and (sticky or lsb):
                    round_up = True
            elif rm == RTZ:  # Round Towards Zero
                pass  # Truncation is default
            elif rm == RPI:  # Round Towards Positive Infinity
                if not sign_bit and (g or sticky):
                    round_up = True
            elif rm == RNI:  # Round Towards Negative Infinity
                if sign_bit and (g or sticky):
                    round_up = True
            elif rm == RNA:  # Round to Nearest, Ties Away from Zero
                if g:
                    round_up = True

            if round_up:
                mant_16 += 1
                if mant_16 >= 0x0400:  # Mantissa overflow
                    mant_16 = mant_16 >> 1
                    exp_16 += 1
                    if exp_16 >= 0x1F:  # Exponent overflow to infinity
                        exp_16 = 0x1F
                        mant_16 = 0

            result_int = sign_bit | (exp_16 << 10) | mant_16

    # Convert the final integer bit-pattern back to a numpy.float16
    result_bytes = result_int.to_bytes(2, "little")
    return np.frombuffer(result_bytes, dtype=np.float16)[0]


def round_fp64_to_fp16(val: np.float64, rm: int) -> np.float16:
    """
    Rounds a float64 value to float16 with a specified rounding mode,
    using bit-accurate logic per IEEE 754.
    """
    f64_bytes = val.tobytes()
    x = int.from_bytes(f64_bytes, "little")

    sign_bit = (x >> 48) & 0x8000  # Shift to fp16 sign position
    exp_64 = (x >> 52) & 0x7FF
    mant_64 = x & 0xFFFFFFFFFFFFF

    if exp_64 == 0x7FF:  # NaN or Infinity
        mant_16 = 0x0200 if mant_64 != 0 else 0
        result_int = sign_bit | 0x7C00 | mant_16
    else:
        exp_16 = exp_64 - 1023 + 15

        if exp_16 >= 0x1F:  # Overflow
            if rm == RNI:
                result_int = 0xFBFF  # Max normal neg number
            elif rm == RTZ and sign_bit:
                result_int = 0xFBFF  # Max normal neg number
            else:
                result_int = sign_bit | 0x7C00  # Infinity
        elif exp_16 <= 0:  # Underflow to denormalized or zero
            if exp_16 < -10:  # Result is too small, flush to zero
                if rm == RPI and not sign_bit:
                    result_int = 0x0001  # Smallest denormal
                elif rm == RNI and sign_bit:
                    result_int = 0x8001  # Smallest denormal
                else:
                    result_int = sign_bit
            else:
                # Create denormalized value
                mant = (mant_64 | (1 << 52)) >> (1 - exp_16)
                lsb = (mant >> 42) & 1
                g = (mant >> 41) & 1
                sticky = (mant & ((1 << 41) - 1)) != 0
                mant_16 = mant >> 42

                if (
                    (rm == RNE and g and (sticky or lsb))
                    or (rm == RNA and g)
                    or (rm == RPI and not sign_bit and (g or sticky))
                    or (rm == RNI and sign_bit and (g or sticky))
                ):
                    mant_16 += 1
                result_int = sign_bit | mant_16
        else:
            # Normalized number
            lsb = (mant_64 >> 42) & 1
            g = (mant_64 >> 41) & 1
            sticky = (mant_64 & ((1 << 41) - 1)) != 0
            mant_16 = mant_64 >> 42

            if (
                (rm == RNE and g and (sticky or lsb))
                or (rm == RNA and g)
                or (rm == RPI and not sign_bit and (g or sticky))
                or (rm == RNI and sign_bit and (g or sticky))
            ):
                mant_16 += 1
                if mant_16 >= 0x0400:  # Mantissa overflow
                    mant_16 = 0
                    exp_16 += 1

            result_int = sign_bit | (exp_16 << 10) | mant_16

    result_bytes = result_int.to_bytes(2, "little")
    return np.frombuffer(result_bytes, dtype=np.float16)[0]


def grs_round(
    value_in: int, sign_in: int, mode: int, input_width: int, output_width: int
) -> int:
    """
    Implements the GRS rounding decision logic, mirroring the Verilog grs_round module.

    Args:
        value_in (int): The unrounded input value (e.g., a mantissa).
        sign_in (int): The sign of the number (0 for positive, 1 for negative).
        mode (int): The rounding mode (RNE, RTZ, etc.).
        input_width (int): The bit width of value_in.
        output_width (int): The desired bit width of the rounded value.

    Returns:
        int: 1 if the value should be incremented, 0 otherwise.
    """
    shift_amount = input_width - output_width

    # If there are no bits to truncate, no rounding is needed.
    if shift_amount <= 0:
        return value_in

    # LSB of the part that will be kept
    lsb = (value_in >> shift_amount) & 1

    # Guard bit: The most significant bit of the truncated portion.
    g = (value_in >> (shift_amount - 1)) & 1 if shift_amount >= 1 else 0

    # Round bit: The bit immediately to the right of the Guard bit.
    r = (value_in >> (shift_amount - 2)) & 1 if shift_amount >= 2 else 0

    # Sticky bit: The logical OR of all bits to the right of the Round bit.
    if shift_amount >= 3:
        mask = (1 << (shift_amount - 2)) - 1
        s = 1 if (value_in & mask) != 0 else 0
    else:
        s = 0

    inexact = g | r | s
    increment = 0

    if mode == RNE:  # Round to Nearest, Ties to Even
        increment = g & (r | s | lsb)
    elif mode == RTZ:  # Round Towards Zero
        increment = 0
    elif mode == RPI:  # Round Towards Positive Infinity
        increment = (1 - sign_in) & inexact
    elif mode == RNI:  # Round Towards Negative Infinity
        increment = sign_in & inexact
    elif mode == RNA:  # Round to Nearest, Ties Away from Zero
        increment = g

    return increment


def fp16_add32(a_hex: str, b_hex: str, rm: int = RNE) -> Dict[str, str]:
    """
    Add two IEEE 754 binary16 (fp16) numbers given as hex strings.

    Parameters:
        a_hex (str): First 16-bit half-precision floating-point value as a hex string (e.g. 'c540').
        b_hex (str): Second 16-bit half-precision floating-point value as a hex string.
        rm (int): The rounding mode to use, matching grs_round.vh.

    Returns:
        Dict[str, str]: Result in multiple formats (fp16 string, hex, bin, dec, oct).
    """

    # Convert hex strings to fp16
    a_fp16 = fp16_parse_hex(a_hex)
    b_fp16 = fp16_parse_hex(b_hex)

    # Perform operation in higher precision (float32) to have bits for rounding
    result_f32 = np.float32(a_fp16) + np.float32(b_fp16)

    # Round the result to fp16 using the specified mode
    c = round_fp32_to_fp16(result_f32, rm)

    print(f"DEBUG: a = {a_fp16}, b = {b_fp16}, c = {c}")
    return fp16_result(c)


def fp16_add16(a_hex: str, b_hex: str, rm: int = RNE) -> Dict[str, str]:
    """
    Add two IEEE 754 binary16 (fp16) numbers given as hex strings.

    Parameters:
        a_hex (str): First 16-bit half-precision floating-point value as a hex string (e.g. 'c540').
        b_hex (str): Second 16-bit half-precision floating-point value as a hex string.
        rm (int): The rounding mode to use, matching grs_round.vh.

    Returns:
        Dict[str, str]: Result in multiple formats (fp16 string, hex, bin, dec, oct).
    """

    # Convert hex strings to fp16
    a_fp16 = fp16_parse_hex(a_hex)
    b_fp16 = fp16_parse_hex(b_hex)

    # Perform operation in higher precision (float64) to have bits for rounding
    result_f64 = np.float64(a_fp16) + np.float64(b_fp16)

    # Round the result to fp16 using the specified mode
    c = round_fp64_to_fp16(result_f64, rm)

    print(f"DEBUG: a = {a_fp16}, b = {b_fp16}, c = {c}")
    return fp16_result(c)

def fp16_add(a_hex: str, b_hex: str, rm: int = RNE) -> Dict[str, str]:
    return fp16_add_ex(a_hex, b_hex, rm, 32)  # Default to 32-bit precision


def fp16_add_ex(
    a_hex: str, b_hex: str, rm: int = RNE, precision_bits: int = 32
) -> Dict[str, str]:
    """
    Adds two fp16 numbers using a configurable intermediate precision,
    and uses the GRS rounding function. This is a bit-accurate model of fp_add.v.

    Args:
        a_hex (str): First fp16 operand as a hex string.
        b_hex (str): Second fp16 operand as a hex string.
        rm (int): The rounding mode to use.
        precision_bits (int): The number of extra bits for intermediate precision.

    Returns:
        Dict[str, str]: The result in multiple formats.
    """
    # FP16 constants
    EXP_W, MANT_W, EXP_BIAS = 5, 10, 15

    # Unpack inputs
    a_int, b_int = int(a_hex, 16), int(b_hex, 16)
    sign_a, exp_a, mant_a = (a_int >> 15) & 1, (a_int >> 10) & 0x1F, a_int & 0x3FF
    sign_b, exp_b, mant_b = (b_int >> 15) & 1, (b_int >> 10) & 0x1F, b_int & 0x3FF

    # Handle special cases (NaN, Inf, Zero)
    is_zero_a = exp_a == 0 and mant_a == 0
    is_zero_b = exp_b == 0 and mant_b == 0
    is_inf_a = exp_a == 31 and mant_a == 0
    is_inf_b = exp_b == 31 and mant_b == 0
    is_nan_a = exp_a == 31 and mant_a != 0
    is_nan_b = exp_b == 31 and mant_b != 0

    if is_nan_a or is_nan_b:
        return fp16_result(np.float16(np.nan))
    if is_inf_a and is_inf_b and sign_a != sign_b:
        return fp16_result(np.float16(np.nan))
    if is_inf_a:
        return fp16_result(fp16_parse_hex(a_hex))
    if is_inf_b:
        return fp16_result(fp16_parse_hex(b_hex))
    if is_zero_a and is_zero_b:
        # +0 + -0 = +0 (RNE), but -0 + -0 = -0
        res_sign = sign_a & sign_b
        c = np.float16("-0.0") if res_sign else np.float16("0.0")
        return fp16_result(c)
    if is_zero_a:
        return fp16_result(fp16_parse_hex(b_hex))
    if is_zero_b:
        return fp16_result(fp16_parse_hex(a_hex))

    # Add implicit bit (1 for normal, 0 for denormal)
    full_mant_a = ((exp_a != 0) << MANT_W) | mant_a
    full_mant_b = ((exp_b != 0) << MANT_W) | mant_b

    # Effective exponents (denormals have exp=1 for calculation)
    eff_exp_a = exp_a if exp_a != 0 else 1
    eff_exp_b = exp_b if exp_b != 0 else 1

    # Align mantissas
    align_mant_w = MANT_W + 1 + precision_bits
    mant_a_aligned = full_mant_a << precision_bits
    mant_b_aligned = full_mant_b << precision_bits

    exp_diff = eff_exp_a - eff_exp_b
    if exp_diff > 0:
        mant_b_aligned >>= exp_diff
        res_exp = eff_exp_a
    else:
        mant_a_aligned >>= -exp_diff
        res_exp = eff_exp_b

    # Add or Subtract
    op_is_sub = sign_a != sign_b
    if op_is_sub:
        if mant_a_aligned >= mant_b_aligned:
            res_mant = mant_a_aligned - mant_b_aligned
            res_sign = sign_a
        else:
            res_mant = mant_b_aligned - mant_a_aligned
            res_sign = sign_b
    else:
        res_mant = mant_a_aligned + mant_b_aligned
        res_sign = sign_a

    if res_mant == 0:
        c = np.float16("-0.0") if rm == RNI and op_is_sub else np.float16("0.0")
        return fp16_result(c)

    # Normalize
    # Find MSB position
    if res_mant > 0:
        msb_pos = res_mant.bit_length() - 1
    else:
        msb_pos = -1

    # Normalized position for implicit bit is at align_mant_w - 1
    norm_pos = align_mant_w - 1
    shift = norm_pos - msb_pos

    if shift > 0:
        res_mant <<= shift
    else:
        res_mant >>= -shift

    res_exp -= shift

    # Rounding
    # The implicit bit is at align_mant_w-1, mantissa is below it.
    # We want to round to MANT_W bits.
    # The input to the rounder is the mantissa without the implicit bit.
    rounder_input_width = align_mant_w - 1
    rounder_output_width = MANT_W
    rounder_input = res_mant & ((1 << rounder_input_width) - 1)

    increment = grs_round(
        rounder_input, res_sign, rm, rounder_input_width, rounder_output_width
    )

    rounded_mant_no_implicit = (
        rounder_input >> (rounder_input_width - rounder_output_width)
    ) + increment

    # Check for mantissa overflow from rounding
    if rounded_mant_no_implicit >> MANT_W:
        res_exp += 1
        rounded_mant_no_implicit >>= 1

    final_mant = rounded_mant_no_implicit & ((1 << MANT_W) - 1)

    # Final checks for overflow/underflow
    if res_exp >= 31:  # Overflow to infinity
        final_exp = 31
        final_mant = 0
    elif res_exp <= 0:  # Underflow to denormal or zero
        # Simplified: flush to zero. A full model would create denormals.
        # TODO: (when needed) Implement denormal values result
        final_exp = 0
        final_mant = 0
    else:
        final_exp = res_exp

    # Pack final result
    result_int = (res_sign << 15) | (final_exp << 10) | final_mant
    c = np.frombuffer(result_int.to_bytes(2, "little"), dtype=np.float16)[0]
    return fp16_result(c)


def fp16_mul(a_hex: str, b_hex: str, rm: int = RNE) -> Dict[str, str]:
    """
    Multiply two IEEE 754 binary16 (fp16) numbers given as hex strings.

    Parameters:
        a_hex (str): First 16-bit half-precision floating-point value as a hex string.
        b_hex (str): Second 16-bit half-precision floating-point value as a hex string.
        rm (int): The rounding mode to use, matching grs_round.vh.

    Returns:
        Dict[str, str]: Result in multiple formats (fp16 string, hex, bin, dec, oct).
    """

    # Convert hex strings to fp16
    a_fp16 = fp16_parse_hex(a_hex)
    b_fp16 = fp16_parse_hex(b_hex)
    # Perform operation in higher precision (float32)
    result_f32 = np.float32(a_fp16) * np.float32(b_fp16)
    # Round the result to fp16 using the specified mode
    c = round_fp32_to_fp16(result_f32, rm)
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

    for cmd in ["add", "mul"]:
        sp = subparsers.add_parser(cmd, help=f"{cmd} two fp16 values")
        sp.add_argument("a", help="First operand (e.g. 0xc540, 50560, 0b1100... or 0o...)")
        sp.add_argument("b", help="Second operand (same format as first)")
        sp.add_argument(
            "--round",
            choices=ROUNDING_MODES.keys(),
            default="rne",
            help="Rounding mode",
        )
    sp = subparsers.add_parser("print", help="Print fp16 numbers as float/scientific")
    sp.add_argument("numbers", nargs="+",
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
        return "hex", "0x"
    if arg.lower().startswith("0b"):
        return "bin", "0b"
    if arg.lower().startswith("0o"):
        return "oct", "0o"
    return "dec", ""

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
    return f"{val:04x}"

def parse_fp16_value(arg: str) -> float:
    """
    Parse any supported fp16 bit-pattern format and return its float value.

    Parameters:
        arg (str): String representing fp16 bit pattern (hex/bin/dec/oct).

    Returns:
        float: The corresponding IEEE 754 half-precision float value.
    """
    hex_str = to_hex_str(arg)
    bytes_val = int(hex_str, 16).to_bytes(2, "little")
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
        rm = ROUNDING_MODES[args.round]
        if args.command == "add":
            result = fp16_add(a_hex, b_hex, rm)
        else:
            result = fp16_mul(a_hex, b_hex, rm)
        # Only print result in matching format, with no markup
        print(prefix + result[fmt])
    elif args.command == "print":
        fp16_print(args.numbers)
    else:
        raise ValueError(f"Invalid command {args.command}")

if __name__ == "__main__":
    main()
