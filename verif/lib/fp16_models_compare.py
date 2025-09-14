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

def compare_fp16_add(a_hex: str, b_hex: str, c_py: str, c_c: str) -> int:
    """
    Compare C and Python fp16_add implementations and print results.

    Args:
        a_hex (str): hex string of first operand.
        b_hex (str): hex string of second operand.
        c_py  (str): hex string of expected Py output.
        c_c   (str): hex string of expected C  output.
    """
    c_result = fp16_add_c(a_hex, b_hex)
    py_result = fp16_add(a_hex, b_hex)['hex']
    exp_py = ""
    exp_c = ""
    s = "PASS"
    res = 0
    if c_py and py_result != c_py:
        exp_py = f", Expected: 0x{c_py}"
        s = "FAIL"
        res = 1
    if not res and c_c and py_result != c_py:
        exp_c = f", Expected: 0x{c_c}"
        s = "FAIL"
        res = 1
    if not res and (not c_py or not c_c) and c_result != py_result:
        exp_py = f", Expected: 0x{c_py}" if c_py else "Expected: 0x{c_result}"
        exp_c = f", Expected: 0x{c_c}" if c_c else "Expected: 0x{py_result}"
        s = "FAIL"
        res = 1
    print(
        f"{s} fp16_add(0x{a_hex}, 0x{b_hex}) results - Python: 0x{py_result}{exp_py}, C: 0x{c_result}{exp_c}"
    )
    if s == "DIFFER":
        vals = [
            "0x" + a_hex,
            "0x" + b_hex,
            "0x" + c_result,
            "0x" + py_result,
        ]
        if c_py:
            vals.append("0x" + c_py)
        fp16_print(vals)
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
        # (   a,      b,   c_py,    c_c),
        # Edge cases
        ("7c01", "3c00", "7e01", "7e00"),  # qNaN +   1.0 -> qNaN, py != C, DUT=7c01=qNaN
        ("4000", "fc01", "fe01", "fe00"),  #  2.0 + -qNaN -> qNaN, py != C, DUT=7c01=qNaN
        ("7c00", "7c00", "7c00", "7c00"),  # +Inf +  +Inf -> +Inf
        ("fc00", "fc00", "fc00", "fc00"),  # -Inf +  -Inf -> -Inf
        ("7c00", "fc00", "fe00", "fe00"),  # +Inf +  -Inf -> qNaN
        ("fc00", "7c00", "fe00", "fe00"),  # -Inf +  +Inf -> qNaN
        ("7c00", "4000", "7c00", "7c00"),  # +Inf +   2.0 -> +Inf
        ("0000", "8000", "0000", "0000"),  #   +0 +    -0 ->   +0
        ("8000", "8000", "8000", "8000"),  #   -0 +    -0 ->   -0
        ("c200", "0000", "c200", "c200"),  #  4.0 +    +0 ->  4.0
        #  Some random test cases
        ("c540", "0000", "c540", "c540"),
        ("c540", "2cab", "c52d", "c52d"),
        ("5a63", "dbdb", "d1e0", "d1e0"),
    ]
    for a, b, c_py, c_c in test_cases:
        exp_str = ""
        if c_py:
            exp_str += f"=0x{c_py}/* py */"
        if c_c:
            exp_str += f"=0x{c_c}/* C */"
        print(f"\nTesting: fp16_add(0x{a}, 0x{b}){exp_str}")
        res += compare_fp16_add(a, b, c_py, c_c)
        total += 1

    if res:
        print(f"FAIL Test: {res} failed of {total} test cases.")
    else:
        print(f"PASS Test: All {total} test cases passed.")
    return 1 if res != 0 else 0

if __name__ == "__main__":
    exit(main())
