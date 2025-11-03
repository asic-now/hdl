#!/usr/bin/env python3

"""
Compares C model to Python model.
"""
# verif/lib/fp16_models_compare.py

import ctypes
from ctypes import CDLL, c_uint16
import platform
import subprocess
import os
import random
from typing import Optional, Tuple

from fp16_model import ROUNDING_MODES, fp16_add, fp16_mul, fp16_print


def get_lib_path():
    """Get the path to the shared library"""
    current_dir = os.path.dirname(os.path.abspath(__file__))
    workspace_root = os.path.abspath(os.path.join(current_dir, "..", ".."))
    if platform.system() == "Windows":
        return os.path.join(workspace_root, "verif", "lib", "libfp16_model.dll")
    else:
        return os.path.join(workspace_root, "verif", "lib", "libfp16_model.so")


libfp16: Optional[CDLL] = None


def load_libfp16() -> CDLL:
    """Load the shared library containing the C model functions"""
    global libfp16  # pylint: disable=global-statement
    if libfp16 is None:
        lib_path = get_lib_path()
        libfp16 = ctypes.CDLL(lib_path)
        libfp16.c_fp16_add.argtypes = [c_uint16, c_uint16, ctypes.c_int]
        libfp16.c_fp16_add.restype = c_uint16
        libfp16.c_fp16_mul.argtypes = [c_uint16, c_uint16, ctypes.c_int]
        libfp16.c_fp16_mul.restype = c_uint16
    return libfp16


def fp16_add_c(a_hex: str, b_hex: str, rm: int) -> str:
    """
    Call the C c_fp16_add() function via ctypes.

    Args:
        a_hex (str): hex string representing a 16-bit half-precision float bit pattern.
        b_hex (str): hex string representing a 16-bit half-precision float bit pattern.
        rm (int): The rounding mode to use.

    Returns:
        str: hex string representing the fp16 bit pattern result.
    """
    lib = load_libfp16()
    a_val = int(a_hex, 16)
    b_val = int(b_hex, 16)
    result = lib.c_fp16_add(c_uint16(a_val), c_uint16(b_val), rm)
    return f"{result:04x}"


def fp16_mul_c(a_hex: str, b_hex: str, rm: int) -> str:
    """
    Call the C c_fp16_mul() function via ctypes.

    Args:
        a_hex (str): hex string representing a 16-bit half-precision float bit pattern.
        b_hex (str): hex string representing a 16-bit half-precision float bit pattern.

    Returns:
        str: hex string representing the fp16 bit pattern result.
    """
    lib = load_libfp16()
    a_val = int(a_hex, 16)
    b_val = int(b_hex, 16)
    result = lib.c_fp16_mul(c_uint16(a_val), c_uint16(b_val), rm)
    return f"{result:04x}"


def canonicalize_fp16_hex(hex_val: str) -> str:
    """
    Canonicalize special FP16 values to prevent mismatches.
    - Converts all NaNs to a standard quiet NaN (0x7e00).
    - Converts -0 to +0.
    """
    val = int(hex_val, 16)
    # sign = (val >> 15) & 1
    exp = (val >> 10) & 0x1F
    mant = val & 0x3FF

    # If exponent is all 1s (NaN or Inf)
    if exp == 0x1F and mant != 0:
        return "7e00"  # Canonical qNaN

    # If value is -0 (0x8000), convert to +0 (0x0000)
    if val == 0x8000:
        return "0000"

    return hex_val


def _compare_and_report(
    op_name: str,
    a_hex: str,
    b_hex: str,
    py_result: str,
    c_result: str,
    c_py_expected: Optional[str],
    c_c_expected: Optional[str],
    rm_str: str,
) -> int:
    """Shared scoreboard function to compare results and report status."""
    c_result_canon = canonicalize_fp16_hex(c_result)
    py_result_canon = canonicalize_fp16_hex(py_result)

    exp_py = ""
    exp_c = ""
    s = "PASS"
    res = 0

    if c_py_expected and py_result_canon != c_py_expected:
        exp_py = f", Expected: 0x{c_py_expected}"
        s = "FAIL"
        res = 1
    if not res and c_c_expected and c_result_canon != c_c_expected:
        exp_c = f", Expected: 0x{c_c_expected}"
        s = "FAIL"
        res = 1
    if (
        not res
        and not c_py_expected
        and not c_c_expected
        and c_result_canon != py_result_canon
    ):
        # exp_py = f", Expected: 0x{c_py}" if c_py else f", Expected: 0x{c_result_canon}"
        # exp_c = f", Expected: 0x{c_c}" if c_c else f", Expected: 0x{py_result_canon}"
        s = "FAIL"
        res = 1

    print(
        f"{s} {op_name}(0x{a_hex}, 0x{b_hex}, {rm_str}) results - Python: 0x{py_result_canon}{exp_py}, C: 0x{c_result_canon}{exp_c}"
    )

    if s != "PASS":
        vals = [
            "0x" + a_hex,
            "0x" + b_hex,
            "0x" + c_result_canon,
            "0x" + py_result_canon,
        ]
        if c_py_expected:
            vals.append("0x" + c_py_expected)
        if c_c_expected:
            vals.append("0x" + c_c_expected)

        # Remove duplicates while preserving order for cleaner output
        seen = set()
        unique_vals = [x for x in vals if not (x in seen or seen.add(x))]

        fp16_print(unique_vals)
    return res


def compare_fp16_add(
    a_hex: str,
    b_hex: str,
    c_py: Optional[str],
    c_c: Optional[str],
    rm_str: str,
) -> int:
    """
    Compare C and Python fp16_add implementations and print results.

    Args:
        a_hex (str): hex string of first operand.
        b_hex (str): hex string of second operand.
        c_py  (str): hex string of expected Py output.
        c_c   (str): hex string of expected C  output.
        rm_str (str): The rounding mode to use (e.g., "rne").
    """
    rm = ROUNDING_MODES[rm_str]
    c_result = fp16_add_c(a_hex, b_hex, rm)
    py_result = fp16_add(a_hex, b_hex, rm)["hex"]
    return _compare_and_report(
        "fp16_add", a_hex, b_hex, py_result, c_result, c_py, c_c, rm_str
    )


def compare_fp16_mul(
    a_hex: str,
    b_hex: str,
    c_py: Optional[str],
    c_c: Optional[str],
    rm_str: str,
) -> int:
    """
    Compare C and Python fp16_mul implementations and print results.

    Args:
        a_hex (str): hex string of first operand.
        b_hex (str): hex string of second operand.
        c_py  (str): hex string of expected Py output.
        c_c   (str): hex string of expected C  output.
        rm_str (str): The rounding mode to use (e.g., "rne").
    """
    rm = ROUNDING_MODES[rm_str]
    c_result = fp16_mul_c(a_hex, b_hex, rm)
    py_result = fp16_mul(a_hex, b_hex, rm)["hex"]
    return _compare_and_report(
        "fp16_mul", a_hex, b_hex, py_result, c_result, c_py, c_c, rm_str
    )


def compile_lib():
    """Compile the C model to shared library"""

    # Release the current library before compiling a new one
    global libfp16  # pylint: disable=global-statement
    libfp16 = None

    # Figure out the workspace root
    current_dir = os.path.dirname(os.path.abspath(__file__))
    workspace_root = os.path.abspath(os.path.join(current_dir, "..", ".."))
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

special_values = [
    "0000",  # +Zero
    "8000",  # -Zero
    "7c00",  # +Inf
    "fc00",  # -Inf
    "7c01",  # +sNaN
    "fc01",  # -sNaN
    "7e00",  # +qNaN (canonical)
    "fe00",  # -qNaN (canonical)
]

def get_add_test_uvm_cases(rm: str) -> list:
    """Generate a list of test cases for fp16_add."""
    add_test_cases = [
        # From failing fp_add test: UVM_ERROR
        ("12d4", "f7e2", None, None, "rpi"),  # DUT=0xf7e1, MODEL=0xf7e2 | Canonical: DUT=0xf7e1, MODEL=0xf7e2
        # ("e3e0", "063e", None, None, "rtz"),  # DUT=0xe3e0, MODEL=0xe3df | Canonical: DUT=0xe3e0, MODEL=0xe3df
        # ("761f", "e2d1", None, None, "rne"),  # DUT=0x75e8, MODEL=0x75e9 | Canonical: DUT=0x75e8, MODEL=0x75e9
        # ("e0be", "11b7", None, None, "rne"),  # DUT=0xe0be, MODEL=0xe0bd | Canonical: DUT=0xe0be, MODEL=0xe0bd
        # ("e0be", "11b7", None, None, "rtz"),  # DUT=0xe0be, MODEL=0xe0bd | Canonical: DUT=0xe0be, MODEL=0xe0bd
        # ("e0be", "11b7", None, None, "rpi"),  # DUT=0xe0be, MODEL=0xe0bd | Canonical: DUT=0xe0be, MODEL=0xe0bd
        # ("e0be", "11b7", None, None, "rni"),  # DUT=0xe0be, MODEL=0xe0bd | Canonical: DUT=0xe0be, MODEL=0xe0bd
        # ("e0be", "11b7", None, None, "rna"),  # DUT=0xe0be, MODEL=0xe0bd | Canonical: DUT=0xe0be, MODEL=0xe0bd
        # ("dedd", "6b8f", None, None, "rna"),  # DUT=0x6ab3, MODEL=0x6ab4 | Canonical: DUT=0x6ab3, MODEL=0x6ab4
        # ("e87e", "2f5d", None, None, "rni"),  # DUT=0xe87d, MODEL=0xe87e | Canonical: DUT=0xe87d, MODEL=0xe87e
        # ("965c", "8c6f", None, None, "rna"),  # DUT=0x9777, MODEL=0x9778 | Canonical: DUT=0x9777, MODEL=0x9778
        # ("6c6a", "d2d3", None, None, "rpi"),  # DUT=0x6c5c, MODEL=0x6c5d | Canonical: DUT=0x6c5c, MODEL=0x6c5d
    ]

    return add_test_cases


def get_add_test_cases(rm: str, random_count: int) -> list:
    """Generate a list of test cases for fp16_add."""
    normal_values = [
        "3c00",  # 1.0
        "c000",  # -2.0
        # "4000",  # 2.0
        # "c200",  # -4.0
        # "c540",  # Representative normal
        # "2cab",  # Representative normal
        # "5a63",  # Representative normal
        # "dbdb",  # Representative normal
        "06f3",  # Denormal
        "0e82",  # Denormal
    ]

    add_test_cases = []

    # Generate permutations of special and normal values
    all_values = special_values + normal_values
    for a in all_values:
        for b in all_values:
            if a in special_values or b in special_values:
                add_test_cases.append((a, b, None, None, rm))
                add_test_cases.append((b, a, None, None, rm))

    # Add a few normal-normal cases to ensure basic functionality is tested
    add_test_cases.extend(
        [
            ("c540", "2cab", None, None, rm),
            ("5a63", "dbdb", None, None, rm),
        ]
    )

    # Generate random test cases with normal numbers
    for _ in range(random_count):
        # Generate a random normal fp16 number
        # Sign: 1 bit, Exp: 5 bits (1-30 for normal), Mant: 10 bits
        a_val = (
            (random.randint(0, 1) << 15)
            | (random.randint(1, 30) << 10)
            | (random.randint(0, 0x3FF))
        )
        b_val = (
            (random.randint(0, 1) << 15)
            | (random.randint(1, 30) << 10)
            | (random.randint(0, 0x3FF))
        )
        add_test_cases.append((f"{a_val:04x}", f"{b_val:04x}", None, None, rm))

    return add_test_cases


def run_add_tests(add_test_cases: list) -> Tuple[int, int]:
    """Run a list of test cases for fp16_add."""
    total = 0
    res = 0

    for a, b, c_py, c_c, rm_str in add_test_cases:
        exp_str = ""
        if c_py:
            exp_str += f"=0x{c_py}/* py */"
        if c_c:
            exp_str += f"=0x{c_c}/* C */"
        print(f"\nTesting: fp16_add(0x{a}, 0x{b}, {rm_str}){exp_str}")
        res += compare_fp16_add(a, b, c_py, c_c, rm_str)
        total += 1
    if res:
        print(f"FAIL ADD Test: {res} failed of {total} test cases.")
    else:
        print(f"PASS ADD Test: All {total} test cases passed.")
    return res, total


def get_mul_test_cases_failed(rm: str) -> list:
    mul_test_cases = [
        ("1286", "8e9c", None, None, "rne"),
    ]
    return mul_test_cases

def get_mul_test_cases(rm: str, random_count: int) -> list:
    """Generate a list of test cases for fp16_mul."""
    normal_values = [
        "3c00",  #  1.0
        "c000",  # -2.0
        "4000",  #  2.0
        "4200",  #  3.0
        "3800",  #  0.5
        "3400",  #  0.25
        "d6b8",
        "8c61",
        "06f3",
        "0e82",
    ]

    mul_test_cases = []
    all_values = special_values + normal_values
    for a in all_values:
        for b in all_values:
            if a in special_values or b in special_values:
                mul_test_cases.append((a, b, None, None, rm))
                mul_test_cases.append((b, a, None, None, rm))

    # Generate random test cases with normal numbers
    for _ in range(random_count):
        # Generate a random normal fp16 number
        # Sign: 1 bit, Exp: 5 bits (1-30 for normal), Mant: 10 bits
        a_val = (
            (random.randint(0, 1) << 15)
            | (random.randint(1, 30) << 10)
            | (random.randint(0, 0x3FF))
        )
        b_val = (
            (random.randint(0, 1) << 15)
            | (random.randint(1, 30) << 10)
            | (random.randint(0, 0x3FF))
        )
        mul_test_cases.append((f"{a_val:04x}", f"{b_val:04x}", None, None, rm))

    return mul_test_cases


def run_mul_tests(mul_test_cases: list) -> Tuple[int, int]:
    """Run a list of test cases for fp16_mul."""
    total = 0
    res = 0

    for a, b, c_py, c_c, rm_str in mul_test_cases:
        print(f"\nTesting: fp16_mul(0x{a}, 0x{b}, {rm_str})")
        res += compare_fp16_mul(a, b, c_py, c_c, rm_str)
        total += 1

    if res:
        print(f"FAIL MUL Test: {res} failed of {total} test cases.")
    else:
        print(f"PASS MUL Test: All {total} test cases passed.")
    return res, total


def main():
    # random_count = 10
    random_count = 100
    # random_count = 1000
    compile_lib()
    res = 0
    rm_results = {}
    # for rm in ["rne", "rtz", "rpi", "rni", "rna"]:
    for rm in ["rpi"]:
        add_cases = get_add_test_uvm_cases(rm)
        # mul_cases = get_mul_test_cases_failed(rm)

        # add_cases = get_add_test_cases(rm, random_count)
        mul_cases = [] # get_mul_test_cases(rm, random_count)

        res_add, total_add = run_add_tests(add_cases)
        res_mul, total_mul = run_mul_tests(mul_cases)
        res += res_add + res_mul
        rm_results[rm] = (res_add, total_add, res_mul, total_mul)

    # Print summary table
    print("\n--- Comparison Summary ---")
    sep = " | "
    col_widths = [8, 15, 20, 20]
    col_headings = [
        "Verdict",
        "Rounding Mode",
        "ADD (errors/total)",
        "MUL (errors/total)",
    ]
    header = sep.join([f"{f:<{col_widths[i]}}" for i, f in enumerate(col_headings)])
    print(header)
    print("-" * (sum(col_widths) + 3 * (len(col_widths) - 1)))
    for rm, (res_add, total_add, res_mul, total_mul) in rm_results.items():
        row_data = [
            "PASS" if res_add + res_mul == 0 else "FAIL",  # verdict
            rm,
            f"{res_add} / {total_add}",  # add_summary
            f"{res_mul} / {total_mul}",  # mul_summary
        ]
        row = sep.join([f"{f:<{col_widths[i]}}" for i, f in enumerate(row_data)])
        print(row)
    rc = min(res, 255)  # Limit the return code to 255 for Posix compatibility.
    return rc

if __name__ == "__main__":
    exit(main())
