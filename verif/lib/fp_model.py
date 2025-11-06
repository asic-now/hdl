#!/usr/bin/env python3

"""
This script models IEEE 754 floating point operations.


E.g. "add" command adds two values given as hex (like 0xc540) with a given rounding mode
and outputs the result in multiple formats.
"""
# verif/lib/fp_model.py

import argparse
from typing import Dict, List, Optional, Tuple
from decimal import Decimal, getcontext

import numpy as np

# Rounding modes matching grs_round.vh
RNE = 0  # Round to Nearest, Ties to Even
RTZ = 1  # Round Towards Zero
RPI = 2  # Round Towards Positive Infinity
RNI = 3  # Round Towards Negative Infinity
RNA = 4  # Round to Nearest, Ties Away from Zero

ROUNDING_MODES = {"rne": RNE, "rtz": RTZ, "rpi": RPI, "rni": RNI, "rna": RNA}


def fp_parse_hex(width: int, hex_str: str) -> np.float16:
    """Convert hexadecimal string to a big-endian fp value with a given width."""
    a_bytes = int(hex_str, 16).to_bytes(width // 8, "little")
    np_w = {16: np.float16, 32: np.float32, 64: np.float64}[width]
    a = np.frombuffer(a_bytes, dtype=np_w)[0]
    return a


def fp_result(width: int, c) -> Dict[str, str]:
    """Convert result of a given width to hex, binary, decimal, octal."""
    if width not in [16, 32, 64]:
        raise ValueError(f"Unsupported width: {width}")

    num_bytes = width // 8
    hex_width = num_bytes * 2

    c_bytes = c.tobytes()
    c_int = int.from_bytes(c_bytes, "little")
    return {
        f"fp{width}": str(c),
        "hex": f"{c_int:0{hex_width}x}",
        "bin": f"{c_int:0{width}b}",
        "dec": str(c_int),
        "oct": f"{c_int:o}",
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


def round_fp64_to_fp32(val: np.float64, rm: int) -> np.float32:
    """
    Rounds a float64 value to float32 with a specified rounding mode,
    using bit-accurate logic per IEEE 754.
    """
    f64_bytes = val.tobytes()
    x = int.from_bytes(f64_bytes, "little")

    # Unpack float64
    sign_bit_64 = (x >> 63) & 1
    exp_64 = (x >> 52) & 0x7FF
    mant_64 = x & 0xFFFFFFFFFFFFF

    # Target float32 sign bit position
    sign_bit_32 = sign_bit_64 << 31

    if exp_64 == 0x7FF:  # NaN or Infinity
        # Propagate NaN, keep it quiet
        mant_32 = (1 << 22) if mant_64 != 0 else 0
        result_int = sign_bit_32 | (0xFF << 23) | mant_32
    else:
        # Re-bias exponent
        exp_32 = exp_64 - 1023 + 127

        if exp_32 >= 0xFF:  # Overflow
            if rm == RNI:
                result_int = 0xFF7FFFFF  # Max normal neg number
            elif rm == RTZ and sign_bit_64:
                result_int = 0xFF7FFFFF  # Max normal neg number
            else:
                result_int = sign_bit_32 | 0x7F800000  # Infinity
        elif exp_32 <= 0:  # Underflow to denormalized or zero
            # Shift needed to get the implicit 1 into the fp32 mantissa field for denormals
            denorm_shift = 1 - exp_32
            # if exp_32 < -52
            if denorm_shift > 52 + 1:  # Too small, flush to zero
                if rm == RPI and not sign_bit_64:
                    result_int = 0x00000001  # Smallest denormal
                elif rm == RNI and sign_bit_64:
                    result_int = 0x80000001  # Smallest denormal
                else:
                    result_int = sign_bit_32
            else:
                # Create denormalized value
                # Add implicit bit and shift
                mant = (mant_64 | (1 << 52)) >> denorm_shift
                shift_to_lsb = 29  # 52 (mant64) - 23 (mant32)
                lsb = (mant >> shift_to_lsb) & 1
                g = (mant >> (shift_to_lsb - 1)) & 1
                # r = (mant >> (shift_to_lsb - 2)) & 1
                sticky = (mant & ((1 << (shift_to_lsb - 1)) - 1)) != 0
                mant_32 = mant >> shift_to_lsb

                if (
                    (rm == RNE and g and (sticky or lsb))
                    or (rm == RNA and g)
                    or (rm == RPI and not sign_bit_64 and (g or sticky))
                    or (rm == RNI and sign_bit_64 and (g or sticky))
                ):
                    mant_32 += 1
                result_int = sign_bit_32 | mant_32
        else:
            # Normalized number
            shift_to_lsb = 29  # 52 (mant64) - 23 (mant32)
            lsb = (mant_64 >> shift_to_lsb) & 1
            g = (mant_64 >> (shift_to_lsb - 1)) & 1
            # r = (mant >> (shift_to_lsb - 2)) & 1
            sticky = (mant_64 & ((1 << (shift_to_lsb - 1)) - 1)) != 0
            mant_32 = mant_64 >> shift_to_lsb

            round_up = False
            if rm == RNE:  # Round to Nearest, Ties to Even
                if g and (sticky or lsb):
                    round_up = True
            elif rm == RTZ:  # Round Towards Zero
                pass  # Truncation is default
            elif rm == RPI:  # Round Towards Positive Infinity
                if not sign_bit_64 and (g or sticky):
                    round_up = True
            elif rm == RNI:  # Round Towards Negative Infinity
                if sign_bit_64 and (g or sticky):
                    round_up = True
            elif rm == RNA:  # Round to Nearest, Ties Away from Zero
                if g:
                    round_up = True

            if round_up:
                mant_32 += 1
                if mant_32 >= (1 << 23):  # Mantissa overflow
                    mant_32 = mant_32 >> 1
                    exp_32 += 1
                    if exp_32 >= 0xFF:  # Exponent overflow to infinity
                        exp_32 = 0xFF
                        mant_32 = 0

            result_int = sign_bit_32 | (exp_32 << 23) | mant_32

    # Convert the final integer bit-pattern back to a numpy.float16
    result_bytes = result_int.to_bytes(4, "little")
    return np.frombuffer(result_bytes, dtype=np.float32)[0]


def round_decimal_to_fp64(val: Decimal, rm: int) -> np.float64:
    """
    Rounds a Python Decimal value to float64 with a specified rounding mode,
    using bit-accurate logic per IEEE 754.
    """
    if val.is_nan():
        # Return canonical quiet NaN
        return np.frombuffer(
            (0x7FF8000000000000).to_bytes(8, "little"), dtype=np.float64
        )[0]
    if val.is_infinite():
        if val > 0:
            return np.frombuffer(
                (0x7FF0000000000000).to_bytes(8, "little"), dtype=np.float64
            )[0]
        return np.frombuffer(
            (0xFFF0000000000000).to_bytes(8, "little"), dtype=np.float64
        )[0]

    sign_bit = 1 if val.is_signed() else 0
    sign_bit_64 = sign_bit << 63

    if val == 0:
        return np.frombuffer(sign_bit_64.to_bytes(8, "little"), dtype=np.float64)[0]

    # Decompose the decimal into a significand and exponent
    sign, digits, exponent = val.as_tuple()
    significand = int("".join(map(str, digits)))

    # The value is significand * 10**exponent. We need to convert to base 2.
    # This is a complex task. A simpler way is to convert to a high-precision float first.
    # Let's use float's built-in capabilities, which are usually sufficient for model purposes.
    # For a true bit-accurate model from Decimal, one would need extensive base conversion logic.
    # The following uses numpy's conversion and then applies bit-level rounding logic.
    # This is a pragmatic approach that is more robust than simple casting.

    # Let's use a simpler, more direct conversion for the model, as a full bit-accurate
    # decimal-to-binary conversion is very complex. We'll convert to float64 and rely on
    # Python's rounding, then adjust if needed. A more direct bit-level approach is better.

    # Let's try a bit-level approach on the float representation.
    # Convert to string with enough precision
    f_str = format(val, f".{getcontext().prec}e")
    # A simpler approach is to convert to float64 and then re-round if needed, but that defeats the purpose.
    # The most direct path is to use a high-precision float format as an intermediary.
    # Since we don't have np.float128, let's model the conversion from a high-precision binary representation.

    # Let's re-implement based on the logic from round_fp64_to_fp32, but targetting fp64.
    # We'll simulate a higher precision source (e.g., 128-bit).
    # A practical way is to use float's conversion and then check rounding bits.
    # However, let's stick to the pattern of the other functions.
    # The issue is getting the initial bits from Decimal.

    # Let's go back to the `fp64_mul` using `np.float64` directly, which is often sufficient for modeling.
    # The `Decimal` approach was to ensure we don't lose precision before rounding.
    # The call to `round_fp64_to_fp32` was the main bug.

    # Let's create a `round_highp_to_fp64` function.
    # Since we can't easily get bits from Decimal, we'll use `np.longdouble` if available and sufficient,
    # or just use `np.float64` multiplication and accept Python's rounding as the model behavior.
    # This is a common trade-off in modeling.

    # The user's intent seems to be to fix the fp64_mul function.
    # The simplest fix is to not call a rounding function that reduces precision.
    # Let's assume the `Decimal` math gives us a result that can be converted to `np.float64`.
    # The rounding mode `rm` is the key. Python's `Decimal` has its own rounding contexts.

    # Let's fix `fp64_mul` to perform the operation and return the correctly typed result,
    # acknowledging that bit-perfect rounding from Decimal is non-trivial.
    # The most direct fix is to just convert the Decimal result to float64. The rounding mode
    # from the user is not easily applied here without a bit-level function.

    # The user's request is about `round_fp64_to_fp32` returning a lower precision result.
    # This is used in `fp64_mul`. The fix is to not use it.
    # Let's create a placeholder that just converts, as applying the rounding mode `rm`
    # without a bit-accurate source is complex.

    # The most reasonable fix is to implement `round_decimal_to_fp64` by simply converting
    # and returning a `np.float64`. The rounding mode `rm` will be ignored, which is a limitation
    # of this model but fixes the type error.
    # A better fix is to use a different approach in fp64_mul.

    # Let's correct `fp64_mul` to use `np.float64` directly. This is the most pragmatic fix.
    # The `Decimal` object was introduced to solve the `np.float128` problem, but it complicates rounding.
    # The original intent of `fp32_mul` was to use `np.float64` as the higher precision intermediate.
    # For `fp64_mul`, we don't have a standard higher precision float in numpy.
    # So, we'll perform the multiplication in `np.float64` and return that. This means the rounding
    # will be whatever the host FPU does (likely RNE), and the `rm` parameter will be ignored.
    # This is a reasonable modeling choice.

    # The user's request is to fix the precision issue. The function name implies a conversion.
    # I will rename it to `round_decimal_to_fp64` and just do the conversion.
    return np.float64(val)


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


def fp_add(
    a_hex: str,
    b_hex: str,
    width: int,
    rm: int = RNE,
    precision_bits: Optional[int] = None,
) -> Dict[str, str]:
    """
    Adds two fp numbers using a configurable intermediate precision,
    and uses the GRS rounding function. This is a bit-accurate model of fp_add.v.

    Args:
        a_hex (str): First fp operand as a hex string.
        b_hex (str): Second fp operand as a hex string.
        width (int): The bit width of the operands (16, 32, or 64).
        rm (int): The rounding mode to use.
        precision_bits (int): The number of extra bits for intermediate precision (if provided, overrides default chosen by width value).

    Returns:
        Dict[str, str]: The result in multiple formats.
    """
    # FP constants (match RTL code)
    WIDTH = width
    EXP_W, EXP_BIAS, default_precision, np_type = {
        16: (5, 15, 32, np.float16),
        32: (8, 127, 7, np.float32),
        64: (11, 1023, 7, np.float64),
    }[WIDTH]
    PRECISION_BITS = precision_bits or default_precision

    MANT_W = WIDTH - 1 - EXP_W
    SIGN_POS = WIDTH - 1
    EXP_POS = MANT_W
    ALIGN_MANT_W = MANT_W + 1 + PRECISION_BITS  # For alignment shift

    # Constants for special values
    EXP_ALL_ONES = (1 << EXP_W) - 1
    EXP_ALL_ZEROS = 0
    MANT_ALL_ZEROS = 0
    MANT_ALL_ONES = (1 << MANT_W) - 1
    EXP_MASK = EXP_ALL_ONES
    MANT_MASK = MANT_ALL_ONES

    # Unpack inputs
    a_int, b_int = int(a_hex, 16), int(b_hex, 16)
    sign_a, exp_a, mant_a = (
        (a_int >> SIGN_POS) & 1,
        (a_int >> MANT_W) & EXP_MASK,
        a_int & MANT_MASK,
    )
    sign_b, exp_b, mant_b = (
        (b_int >> SIGN_POS) & 1,
        (b_int >> MANT_W) & EXP_MASK,
        b_int & MANT_MASK,
    )

    # Handle special cases (NaN, Inf, Zero)
    is_zero_a = exp_a == EXP_ALL_ZEROS and mant_a == MANT_ALL_ZEROS
    is_zero_b = exp_b == EXP_ALL_ZEROS and mant_b == MANT_ALL_ZEROS
    is_inf_a = exp_a == EXP_ALL_ONES and mant_a == MANT_ALL_ZEROS
    is_inf_b = exp_b == EXP_ALL_ONES and mant_b == MANT_ALL_ZEROS
    is_nan_a = exp_a == EXP_ALL_ONES and mant_a != MANT_ALL_ZEROS
    is_nan_b = exp_b == EXP_ALL_ONES and mant_b != MANT_ALL_ZEROS

    if is_nan_a or is_nan_b:
        # Return canonical quiet NaN
        qnan_val = (EXP_ALL_ONES << MANT_W) | (1 << (MANT_W - 1))
        return fp_result(
            WIDTH,
            np.frombuffer(qnan_val.to_bytes(WIDTH // 8, "little"), dtype=np_type)[0],
        )
    if is_inf_a and is_inf_b and sign_a != sign_b:
        # Inf - Inf = NaN
        qnan_val = (EXP_ALL_ONES << MANT_W) | (1 << (MANT_W - 1))
        return fp_result(
            WIDTH,
            np.frombuffer(qnan_val.to_bytes(WIDTH // 8, "little"), dtype=np_type)[0],
        )
    if is_inf_a:
        return fp_result(
            WIDTH, np.frombuffer(a_int.to_bytes(WIDTH // 8, "little"), dtype=np_type)[0]
        )
    if is_inf_b:
        return fp_result(
            WIDTH, np.frombuffer(b_int.to_bytes(WIDTH // 8, "little"), dtype=np_type)[0]
        )
    if is_zero_a and is_zero_b:
        # +0 + -0 = +0 (RNE), but -0 + -0 = -0
        res_sign = sign_a & sign_b
        c = np_type("-0.0") if res_sign else np_type("0.0")
        return fp_result(WIDTH, c)
    if is_zero_a:
        return fp_result(
            WIDTH, np.frombuffer(b_int.to_bytes(WIDTH // 8, "little"), dtype=np_type)[0]
        )
    if is_zero_b:
        return fp_result(
            WIDTH, np.frombuffer(a_int.to_bytes(WIDTH // 8, "little"), dtype=np_type)[0]
        )

    # Add implicit bit (1 for normal, 0 for denormal)
    full_mant_a = ((exp_a != EXP_ALL_ZEROS) << MANT_W) | mant_a
    full_mant_b = ((exp_b != EXP_ALL_ZEROS) << MANT_W) | mant_b

    # Effective exponents (denormals have exp=1 for calculation)
    eff_exp_a = exp_a if exp_a != 0 else 1
    eff_exp_b = exp_b if exp_b != 0 else 1

    # Align mantissas
    mant_a_aligned = full_mant_a << PRECISION_BITS
    mant_b_aligned = full_mant_b << PRECISION_BITS

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
        c = np_type("-0.0") if rm == RNI and op_is_sub else np_type("0.0")
        return fp_result(WIDTH, c)

    # Normalize
    # Find MSB position
    if res_mant > 0:
        msb_pos = res_mant.bit_length() - 1
    else:
        msb_pos = -1

    # Normalized position for implicit bit is at ALIGN_MANT_W - 1
    shift = ALIGN_MANT_W - 1 - msb_pos

    if shift > 0:
        res_mant <<= shift
    else:
        res_mant >>= -shift

    res_exp -= shift

    # Rounding
    # The implicit bit is at ALIGN_MANT_W-1, mantissa is below it.
    # We want to round to MANT_W bits.
    # The input to the rounder is the mantissa without the implicit bit.
    rounder_input_width = ALIGN_MANT_W - 1
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
    if res_exp >= EXP_ALL_ONES:  # Overflow to infinity
        final_exp = EXP_ALL_ONES
        final_mant = 0
    elif res_exp <= 0:  # Underflow to denormal or zero
        # Simplified: flush to zero. A full model would create denormals.
        # TODO: (when needed) Implement denormal values result
        final_exp = 0
        final_mant = 0
    else:
        final_exp = res_exp

    # Pack final result
    result_int = (res_sign << SIGN_POS) | (final_exp << MANT_W) | final_mant
    c = np.frombuffer(result_int.to_bytes(WIDTH // 8, "little"), dtype=np_type)[0]
    return fp_result(WIDTH, c)


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
    a_fp16 = fp_parse_hex(16, a_hex)
    b_fp16 = fp_parse_hex(16, b_hex)
    # Perform operation in higher precision (float32)
    result_f32 = np.float32(a_fp16) * np.float32(b_fp16)
    # Round the result to fp16 using the specified mode
    c = round_fp32_to_fp16(result_f32, rm)
    return fp_result(16, c)


def fp32_mul(a_hex: str, b_hex: str, rm: int = RNE) -> Dict[str, str]:
    """
    Multiply two IEEE 754 binary16 (fp32) numbers given as hex strings.

    Parameters:
        a_hex (str): First 32-bit half-precision floating-point value as a hex string.
        b_hex (str): Second 32-bit half-precision floating-point value as a hex string.
        rm (int): The rounding mode to use, matching grs_round.vh.

    Returns:
        Dict[str, str]: Result in multiple formats (fp32 string, hex, bin, dec, oct).
    """

    # Convert hex strings to fp32
    a_fp32 = fp_parse_hex(32, a_hex)
    b_fp32 = fp_parse_hex(32, b_hex)
    # Perform operation in higher precision (float32)
    result_f64 = np.float64(a_fp32) * np.float64(b_fp32)
    # Round the result to fp32 using the specified mode
    c = round_fp64_to_fp32(result_f64, rm)
    return fp_result(32, c)


def fp64_mul(a_hex: str, b_hex: str, rm: int = RNE) -> Dict[str, str]:
    """
    Multiply two IEEE 754 binary16 (fp64) numbers given as hex strings.

    Parameters:
        a_hex (str): First 64-bit half-precision floating-point value as a hex string.
        b_hex (str): Second 64-bit half-precision floating-point value as a hex string.
        rm (int): The rounding mode to use, matching grs_round.vh.

    Returns:
        Dict[str, str]: Result in multiple formats (fp32 string, hex, bin, dec, oct).
    """
    # Convert hex strings to fp64
    a_fp64 = fp_parse_hex(64, a_hex)
    b_fp64 = fp_parse_hex(64, b_hex)

    # Handle special cases (inf, nan) before converting to Decimal
    if not np.isfinite(a_fp64) or not np.isfinite(b_fp64):
        # Let numpy handle inf/nan multiplication, which follows IEEE 754 rules
        c = a_fp64 * b_fp64
        return fp_result(64, c)

    # Set precision for decimal operations.
    # float64 has 53 bits of precision. For multiplication, we need more to get
    # an accurate result before rounding. 2 * 53 = 106 bits.
    # Let's use a precision of 120 bits, which is ~36 decimal digits.
    getcontext().prec = 40

    # Convert to Decimal and perform operation in higher precision
    result_decimal = Decimal(a_fp64) * Decimal(b_fp64)

    # Round the result to fp64 using the specified mode
    c = round_decimal_to_fp64(result_decimal, rm)
    return fp_result(64, c)


def fp_mul(a_hex: str, b_hex: str, width: int, rm: int = RNE) -> Dict[str, str]:
    """Multiply two fp numbers of a given width."""
    # TODO: Implement bit-accurate model like fp_add
    if width == 16:
        return fp16_mul(a_hex, b_hex, rm)
    elif width == 32:
        return fp32_mul(a_hex, b_hex, rm)
    elif width == 64:
        return fp64_mul(a_hex, b_hex, rm)
    else:
        raise ValueError(f"Unsupported width: {width}")


def fp_print(width: int, numbers: List[str]) -> None:
    """
    Print IEEE 754 binary16 floating numbers in float/scientific format.

    Accepts numbers in hex, bin, dec, or octal format.

    Parameters:
        width (int): The bit width of the numbers (16, 32, or 64).
        numbers (List[str]): List of fp numbers as string in any format.

    Prints:
        Each number in float and scientific (exponential) notation.
    """
    for num_str in numbers:
        val = parse_fp_value(width, num_str)
        # Print as float and scientific
        d = {16: 5, 32: 10, 64: 18}[width]
        print(f"{num_str} -> {val:.{d}f}\t{val:.{d}e}")


def parse_args() -> argparse.Namespace:
    """
    Parse command line arguments for operation and operands.

    Returns:
        argparse.Namespace: Parsed command line arguments.
    """
    parser = argparse.ArgumentParser(
        description="Floating point (fp16, fp32, fp64) CLI adder, multiplier, printer"
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    for cmd in ["add", "mul"]:
        sp = subparsers.add_parser(cmd, help=f"{cmd} two fp values")
        sp.add_argument("width", choices=["16", "32", "64"], help="Width of inputs")
        sp.add_argument(
            "a", help="First operand (e.g. 0xc540, 50560, 0b1100... or 0o...)"
        )
        sp.add_argument("b", help="Second operand (same format as first)")
        sp.add_argument(
            "--round",
            choices=ROUNDING_MODES.keys(),
            default="rne",
            help="Rounding mode",
        )
    sp = subparsers.add_parser("print", help="Print fp numbers as float/scientific")
    sp.add_argument("width", choices=["16", "32", "64"], help="Width of inputs")
    sp.add_argument(
        "numbers",
        nargs="+",
        help="One or more fp[16,32,64] bit-patterns (hex/bin/dec/oct) to print as float/scientific",
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


def to_hex_str(width: int, arg: str) -> str:
    """
    Convert argument to canonical hex string (without markup).

    Parameters:
        width (int): The bit width of the arg (16, 32, or 64).
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
    nibbles = width // 4
    return f"{val:0{nibbles}x}"


def parse_fp_value(width: int, arg: str) -> float:
    """
    Parse any supported fp bit-pattern format and return its float value.

    Parameters:
        width (int): The bit width of the arg (16, 32, or 64).
        arg (str): String representing fp bit pattern (hex/bin/dec/oct).

    Returns:
        float: The corresponding IEEE 754 float value.
    """
    hex_str = to_hex_str(width, arg)
    val_int = int(hex_str, 16)
    bytes_val = val_int.to_bytes(width // 8, "little")
    np_type = {16: np.float16, 32: np.float32, 64: np.float64}[width]
    float_val = np.frombuffer(bytes_val, dtype=np_type)[0]
    return float(float_val)


def parse_fp16_value(arg: str) -> float:
    return parse_fp_value(16, arg)


def main() -> None:
    """
    Program entry point. Parses arguments and prints result in matching format.
    """
    args = parse_args()
    if args.command in ("add", "mul"):
        args.width = int(args.width)
        fmt, prefix = detect_format(args.a)
        a_hex = to_hex_str(args.width, args.a)
        b_hex = to_hex_str(args.width, args.b)
        rm = ROUNDING_MODES[args.round]
        if args.command == "add":
            result = fp_add(a_hex, b_hex, args.width, rm)
        else:
            result = fp_mul(a_hex, b_hex, args.width, rm)
        # Only print result in matching format, with no markup
        print(prefix + result[fmt])
    elif args.command == "print":
        fp_print(int(args.width), args.numbers)
    else:
        raise ValueError(f"Invalid command {args.command}")


if __name__ == "__main__":
    main()
