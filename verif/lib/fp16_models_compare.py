#!/usr/bin/env python3

"""
Compares C model to Python model.
"""

import ctypes
from ctypes import CDLL, c_uint16
import platform
import subprocess
import os
from typing import Optional

from fp16_model import fp16_add, fp16_print

def get_lib_path():
    """Get the path to the shared library"""
    current_dir = os.path.dirname(os.path.abspath(__file__))
    workspace_root = os.path.abspath(os.path.join(current_dir, '..', '..'))
    if platform.system() == "Windows":
        return os.path.join(workspace_root, "verif", "lib", "libfp16_model.dll")
    else:
        return os.path.join(workspace_root, "verif", "lib", "libfp16_model.so")

libfp16: Optional[CDLL] = None

def load_libfp16() -> CDLL:
    """Load the shared library containing the C c_fp16_add function"""
    global libfp16 # pylint: disable=global-statement
    if libfp16 is None:
        lib_path = get_lib_path()
        libfp16 = ctypes.CDLL(lib_path)
        libfp16.c_fp16_add.argtypes = [c_uint16, c_uint16]
        libfp16.c_fp16_add.restype = c_uint16
    return libfp16

def fp16_add_c(a_hex: str, b_hex: str) -> str:
    """
    Call the C c_fp16_add() function via ctypes.

    Args:
        a_hex (str): hex string representing a 16-bit half-precision float bit pattern.
        b_hex (str): hex string representing a 16-bit half-precision float bit pattern.

    Returns:
        str: hex string representing the fp16 bit pattern result.
    """
    lib = load_libfp16()
    a_val = int(a_hex, 16)
    b_val = int(b_hex, 16)
    result = lib.c_fp16_add(c_uint16(a_val), c_uint16(b_val))
    return f'{result:04x}'

def compare_fp16_add(a_hex: str, b_hex: str) -> int:
    """
    Compare C and Python fp16_add implementations and print results.

    Args:
        a_hex (str): hex string of first operand.
        b_hex (str): hex string of second operand.
    """
    c_result = fp16_add_c(a_hex, b_hex)
    py_result = fp16_add(a_hex, b_hex)['hex']
    if c_result == py_result:
        s = "MATCH"
        res = 0
    else:
        s = "DIFFER"
        res = 1
    print(f"{s} fp16_add(0x{a_hex}, 0x{b_hex}) results - C: 0x{c_result}, Python: 0x{py_result}")
    if s == "DIFFER":
        fp16_print(['0x'+a_hex, '0x'+b_hex, '0x'+c_result, '0x'+py_result])
    return res

def compile_lib():
    """Compile the C model to shared library"""

    # Release the current library before compiling a new one
    global libfp16 # pylint: disable=global-statement
    libfp16 = None

    # Figure out the workspace root
    current_dir = os.path.dirname(os.path.abspath(__file__))
    workspace_root = os.path.abspath(os.path.join(current_dir, '..', '..'))
    print(f"Working directory: {workspace_root}")

    # TODO: (when needed) Add DSim's include path for OS and installed version.
    c_src_path = os.path.join(workspace_root, "verif", "lib", "fp16_model.c")
    lib_path = get_lib_path()

    if platform.system() == "Windows":
        inc = "-IC:/Program Files/Altair/DSim/2025.1/include"
        lib_path = lib_path.replace("\\", "/")
        c_src_path = c_src_path.replace("\\", "/")
        cmd = f'gcc -shared -o "{lib_path}" "{c_src_path}" "{inc}"'
    else:
        inc = "-I/opt/Altair/DSim/2025.1/include"  # Assuming Linux path
        cmd = f'gcc -shared -fPIC -o "{lib_path}" "{c_src_path}" "{inc}"'

    if os.path.exists(lib_path):
        os.remove(lib_path)
        print(f"Removed old shared library: {lib_path}")

    print(f"Running: {cmd}")

    result = subprocess.run(cmd, cwd=workspace_root, shell=True, check=True)

    # Reload the library after compilation
    load_libfp16()

    return result

def main():
    """Example test"""
    compile_lib()
    total = 0
    res = 0

    test_cases = [
        ('c540', '0000'),
        ('c540', '2cab'),
        ('5a63', 'dbdb'),
    ]
    for a, b in test_cases:
        print(f"Testing: fp16_add(0x{a}, 0x{b})")
        res += compare_fp16_add(a, b)
        total += 1

    if res:
        print(f"FAIL Test: {res} failed of {total} test cases.")
    else:
        print(f"PASS Test: All {total} test cases passed.")
    return 1 if res != 0 else 0

if __name__ == "__main__":
    exit(main())
