#!/usr/bin/env python3

"""Compares C model to Python model"""

import ctypes
from ctypes import c_uint16

from fp16_model import fp16_add

# $ gcc -shared -o libfp16_mopdel.so -fPIC fp16_model.c)

# Load the shared library containing the C fp16_add function
libfp16 = ctypes.CDLL('./libfp16_mopdel.so')  # Adjust path/filename as needed

# Specify argument and return types for fp16_add
libfp16.fp16_add.argtypes = [c_uint16, c_uint16]
libfp16.fp16_add.restype = c_uint16

def fp16_add_c(a_hex: str, b_hex: str) -> str:
    """
    Call the C fp16_add function via ctypes.

    Args:
        a_hex (str): hex string representing a 16-bit half-precision float bit pattern.
        b_hex (str): hex string representing a 16-bit half-precision float bit pattern.

    Returns:
        str: hex string representing the fp16 bit pattern result.
    """
    a_val = int(a_hex, 16)
    b_val = int(b_hex, 16)
    result = libfp16.fp16_add(c_uint16(a_val), c_uint16(b_val))
    return f'{result:04x}'

def compare_fp16_add(a_hex: str, b_hex: str) -> None:
    """
    Compare C and Python fp16_add implementations and print results.

    Args:
        a_hex (str): hex string of first operand.
        b_hex (str): hex string of second operand.
    """
    c_result = fp16_add_c(a_hex, b_hex)
    py_result = fp16_add(a_hex, b_hex)['hex']
    print(f"C fp16_add result:    0x{c_result}")
    print(f"Python fp16_add result: 0x{py_result}")
    if c_result == py_result:
        print("Results MATCH")
    else:
        print("Results DIFFER")

def main():
    """Example test"""
    compare_fp16_add('c540', '2cab')

if __name__ == "__main__":
    main()
