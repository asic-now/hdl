#!/usr/bin/env python3

"""
Compares C model to Python model.
"""
# verif/lib/fp_models_compare.py

import ctypes
from ctypes import CDLL, c_uint16, c_uint32, c_uint64
import platform
import subprocess
import os
import random
from typing import Optional, Tuple

from fp_model import (
    ROUNDING_MODES,
    fp16_print,
    fp_add as fp_add_py,
    fp_mul as fp_mul_py,
)

def get_lib_path():
    """Get the path to the shared library"""
    current_dir = os.path.dirname(os.path.abspath(__file__))
    workspace_root = os.path.abspath(os.path.join(current_dir, "..", ".."))
    if platform.system() == "Windows":
        return os.path.join(workspace_root, "verif", "lib", "libfp16_model.dll")
    return os.path.join(workspace_root, "verif", "lib", "libfp16_model.so")


libfp: Optional[CDLL] = None


def load_libfp() -> CDLL:
    """Load the shared library containing the C model functions"""
    global libfp  # pylint: disable=global-statement
    if libfp is None:
        lib_path = get_lib_path()
        libfp = ctypes.CDLL(lib_path)
        # FP16
        libfp.c_fp16_add.argtypes = [c_uint16, c_uint16, ctypes.c_int]
        libfp.c_fp16_add.restype = c_uint16
        libfp.c_fp16_mul.argtypes = [c_uint16, c_uint16, ctypes.c_int]
        libfp.c_fp16_mul.restype = c_uint16
        # FP32
        libfp.c_fp32_add.argtypes = [c_uint32, c_uint32, ctypes.c_int]
        libfp.c_fp32_add.restype = c_uint32
        libfp.c_fp32_mul.argtypes = [c_uint32, c_uint32, ctypes.c_int]
        libfp.c_fp32_mul.restype = c_uint32
        # FP64
        libfp.c_fp64_add.argtypes = [c_uint64, c_uint64, ctypes.c_int]
        libfp.c_fp64_add.restype = c_uint64
        libfp.c_fp64_mul.argtypes = [c_uint64, c_uint64, ctypes.c_int]
        libfp.c_fp64_mul.restype = c_uint64
    return libfp


def fp_add_c(a_hex: str, b_hex: str, width: int, rm: int) -> str:
    """
    Call the C c_fp16_add() function via ctypes.

    Args:
        a_hex (str): hex string representing a 16-bit half-precision float bit pattern.
        b_hex (str): hex string representing a 16-bit half-precision float bit pattern.
        rm (int): The rounding mode to use.
        width (int): The bit width (16, 32, or 64).

    Returns:
        str: hex string representing the fp16 bit pattern result.
    """
    lib = load_libfp()
    if width == 16:
        a_val, b_val = int(a_hex, 16), int(b_hex, 16)
        result = lib.c_fp16_add(c_uint16(a_val), c_uint16(b_val), rm)
    elif width == 32:
        a_val, b_val = int(a_hex, 16), int(b_hex, 16)
        result = lib.c_fp32_add(c_uint32(a_val), c_uint32(b_val), rm)
    elif width == 64:
        a_val, b_val = int(a_hex, 16), int(b_hex, 16)
        result = lib.c_fp64_add(c_uint64(a_val), c_uint64(b_val), rm)
    else:
        raise ValueError(f"Unsupported width for C model: {width}")

    return f"{result:0{width // 4}x}"


def fp_mul_c(a_hex: str, b_hex: str, width: int, rm: int) -> str:
    """
    Call the C c_fp<width>_mul() function via ctypes.

    Args:
        a_hex (str): hex string representing a 16-bit half-precision float bit pattern.
        b_hex (str): hex string representing a 16-bit half-precision float bit pattern.
        width (int): The bit width (16, 32, or 64).
        rm (int): The rounding mode to use.

    Returns:
        str: hex string representing the fp16 bit pattern result.
    """
    lib = load_libfp()
    if width == 16:
        a_val, b_val = int(a_hex, 16), int(b_hex, 16)
        result = lib.c_fp16_mul(c_uint16(a_val), c_uint16(b_val), rm)
    elif width == 32:
        a_val, b_val = int(a_hex, 16), int(b_hex, 16)
        result = lib.c_fp32_mul(c_uint32(a_val), c_uint32(b_val), rm)
    elif width == 64:
        a_val, b_val = int(a_hex, 16), int(b_hex, 16)
        result = lib.c_fp64_mul(c_uint64(a_val), c_uint64(b_val), rm)
    else:
        raise ValueError(f"Unsupported width for C model: {width}")

    return f"{result:0{width // 4}x}"


def get_special_fp_hex(width: int, name: str) -> str:
    """Returns the hex string for a special FP value of a given width."""
    w = width
    e, m = {
        16: (5, 10),
        32: (8, 23),
        64: (11, 52),
    }[width]
    vals = {
        "+zero": 0,
        "-zero": 1 << (w - 1),
        "+inf": ((1 << e) - 1) << m,
        "-inf": (1 << (w - 1)) | (((1 << e) - 1) << m),
        # qNaN: exp all 1s, mantissa MSB is 1
        "qnan": (((1 << e) - 1) << m) | (1 << (m - 1)),
        "+qnan": (((1 << e) - 1) << m) | (1 << (m - 1)),
        "-qnan": (1 << (w - 1)) | (((1 << e) - 1) << m) | (1 << (m - 1)),
        # sNaN: exp all 1s, mantissa MSB is 0, rest is non-zero
        "snan": (((1 << e) - 1) << m) | 1,
        "+snan": (((1 << e) - 1) << m) | 1,
        "-snan": (1 << (w - 1)) | (((1 << e) - 1) << m) | 1,
    }
    return f"{vals[name]:0{w // 4}x}"

def canonicalize_fp_hex(width: int, hex_val: str) -> str:
    """
    Canonicalize special FP values to prevent mismatches.
    - Converts all NaNs to a standard quiet NaN (0x7e00).
    - Converts -0 to +0.
    """
    val = int(hex_val, 16)

    if width == 16:
        exp_w, mant_w = 5, 10
    elif width == 32:
        exp_w, mant_w = 8, 23
    elif width == 64:
        exp_w, mant_w = 11, 52
    else:
        return hex_val  # No canonicalization for unknown widths

    qnan = get_special_fp_hex(width, "+qnan")
    neg_zero = int(get_special_fp_hex(width, "-zero"), 16)

    exp = (val >> mant_w) & ((1 << exp_w) - 1)
    mant = val & ((1 << mant_w) - 1)

    # If exponent is all 1s (NaN or Inf)
    if exp == ((1 << exp_w) - 1) and mant != 0:
        return qnan
    if val == neg_zero:
        return "0" * (width // 4)

    return hex_val


def _compare_and_report(
    op_name: str,
    a_hex: str,
    b_hex: str,
    width: int,
    py_result: str,
    c_result: str,
    c_py_expected: Optional[str],
    c_c_expected: Optional[str],
    rm_str: str,
) -> int:
    """Shared scoreboard function to compare results and report status."""
    c_result_canon = canonicalize_fp_hex(width, c_result)
    py_result_canon = canonicalize_fp_hex(width, py_result)

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
        f"{s} fp{width}_{op_name}(0x{a_hex}, 0x{b_hex}, {rm_str}) results - Python: 0x{py_result_canon}{exp_py}, C: 0x{c_result_canon}{exp_c}"
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


def compare_fp_add(
    a_hex: str,
    b_hex: str,
    width: int,
    c_py: Optional[str],
    c_c: Optional[str],
    rm_str: str,
) -> int:
    """
    Compare C and Python fp_add implementations and print results.

    Args:
        a_hex (str): hex string of first operand.
        b_hex (str): hex string of second operand.
        width (int): The bit width (16, 32, or 64).
        c_py  (str): hex string of expected Py output.
        c_c   (str): hex string of expected C  output.
        rm_str (str): The rounding mode to use (e.g., "rne").
    """
    rm = ROUNDING_MODES[rm_str]
    c_result = fp_add_c(a_hex, b_hex, width, rm)
    py_result = fp_add_py(a_hex, b_hex, width, rm)["hex"]
    return _compare_and_report(
        "add", a_hex, b_hex, width, py_result, c_result, c_py, c_c, rm_str
    )


def compare_fp_mul(
    a_hex: str,
    b_hex: str,
    width: int,
    c_py: Optional[str],
    c_c: Optional[str],
    rm_str: str,
) -> int:
    """
    Compare C and Python fp_mul implementations and print results.

    Args:
        a_hex (str): hex string of first operand.
        b_hex (str): hex string of second operand.
        width (int): The bit width (16, 32, or 64).
        c_py  (str): hex string of expected Py output.
        c_c   (str): hex string of expected C  output.
        rm_str (str): The rounding mode to use (e.g., "rne").
    """
    rm = ROUNDING_MODES[rm_str]
    c_result = fp_mul_c(a_hex, b_hex, width, rm)
    py_result = fp_mul_py(a_hex, b_hex, width, rm)["hex"]
    return _compare_and_report(
        "mul", a_hex, b_hex, width, py_result, c_result, c_py, c_c, rm_str
    )


def compile_lib():
    """Compile the C model to shared library"""

    # Release the current library before compiling a new one
    global libfp  # pylint: disable=global-statement
    libfp = None

    # Figure out the workspace root
    current_dir = os.path.dirname(os.path.abspath(__file__))
    workspace_root = os.path.abspath(os.path.join(current_dir, "..", ".."))
    print(f"Working directory: {workspace_root}")

    # TODO: (when needed) Add DSim's include path for OS and installed version.
    c_src_paths = [
        os.path.join(workspace_root, "verif", "lib", "fp16_model.c"),
        os.path.join(workspace_root, "verif", "lib", "fp32_model.c"),
        os.path.join(workspace_root, "verif", "lib", "fp64_model.c"),
    ]
    lib_path = get_lib_path()

    if platform.system() == "Windows":
        inc = "-IC:/Program Files/Altair/DSim/2025.1/include"
        lib_path = lib_path.replace("\\", "/")
        c_src_paths_str = " ".join([f'"{p.replace("\\", "/")}"' for p in c_src_paths])
        cmd = f'gcc -shared -o "{lib_path}" {c_src_paths_str} "{inc}"'
    else:
        inc = "-I/opt/Altair/DSim/2025.1/include"  # Assuming Linux path
        c_src_paths_str = " ".join([f'"{p}"' for p in c_src_paths])
        cmd = f'gcc -shared -fPIC -o "{lib_path}" {c_src_paths_str} "{inc}"'

    if os.path.exists(lib_path):
        os.remove(lib_path)
        print(f"Removed old shared library: {lib_path}")

    print(f"Running: {cmd}")

    result = subprocess.run(cmd, cwd=workspace_root, shell=True, check=True)

    # Reload the library after compilation
    load_libfp()

    return result


def get_add_test_uvm_cases(width: int, _rm: str) -> list:
    """Generate a list of test cases for fp16_add."""
    add16_test_cases = [
        # From failing fp_add test: UVM_ERROR
        ("899c", "0974", None, None, "rpi"),
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

    return {16: add16_test_cases, 32: [], 64: []}[width]


def get_add_test_cases(width: int, rm: str, random_count: int) -> list:
    """Generate a list of test cases for fp_add for a given width."""
    special_names = [
        "+zero",
        "-zero",
        "+inf",
        "-inf",
        "+qnan",
        "-qnan",
        "+snan",
        "-snan",
    ]
    special_values = [get_special_fp_hex(width, name) for name in special_names]

    # Width-specific tables of normal and denormal values
    # These can be expanded with failing cases from RTL sims or random runs.
    normal_denormal_vals = {
        16: [
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
            "02ab",  # Denormal
            "82ab",  # Denormal (negative)
            "0001",  # Smallest denormal
        ],
        32: [
            "3f800000",  # 1.0
            "c0000000",  # -2.0
            "40000000",  # 2.0
            "00400001",  # Denormal
            "80400001",  # Denormal (negative)
            "00000001",  # Smallest denormal
        ],
        64: [
            "3ff0000000000000",  # 1.0
            "c000000000000000",  # -2.0
            "4000000000000000",  # 2.0
            "0008000000000001",  # Denormal
            "8008000000000001",  # Denormal (negative)
            "0000000000000001",  # Smallest denormal
        ],
    }

    # Select the values for the current width
    normal_values = normal_denormal_vals[width]

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
            (
                f"{0xC540 << (width - 16):0{width // 4}x}",
                f"{0x2CAB << (width - 16):0{width // 4}x}",
                None,
                None,
                rm,
            ),
            (
                f"{0x5A63 << (width - 16):0{width // 4}x}",
                f"{0xDBDB << (width - 16):0{width // 4}x}",
                None,
                None,
                rm,
            ),
        ]
    )

    # Determine exponent range for normal numbers
    exp_w = {16: 5, 32: 8, 64: 11}[width]
    mant_w = {16: 10, 32: 23, 64: 52}[width]
    max_exp = (1 << exp_w) - 2  # Max normal exponent

    # Generate random test cases with normal numbers
    for _ in range(random_count):
        a_val = (
            (random.randint(0, 1) << (width - 1))
            | (random.randint(1, max_exp) << mant_w)
            | (random.randint(0, (1 << mant_w) - 1))
        )
        b_val = (
            (random.randint(0, 1) << (width - 1))
            | (random.randint(1, max_exp) << mant_w)
            | (random.randint(0, (1 << mant_w) - 1))
        )
        add_test_cases.append(
            (f"{a_val:0{width // 4}x}", f"{b_val:0{width // 4}x}", None, None, rm)
        )

    return add_test_cases


def run_add_tests(width: int, add_test_cases: list) -> Tuple[int, int]:
    """Run a list of test cases for fp_add."""
    total = 0
    res = 0

    for a, b, c_py, c_c, rm_str in add_test_cases:
        exp_str = ""
        if c_py:
            exp_str += f"=0x{c_py}/* py */"
        if c_c:
            exp_str += f"=0x{c_c}/* C */"
        print(f"\nTesting: fp{width}_add(0x{a}, 0x{b}, {rm_str}){exp_str}")
        res += compare_fp_add(a, b, width, c_py, c_c, rm_str)
        total += 1
    if res:
        print(f"FAIL ADD Test: {res} failed of {total} test cases.")
    else:
        print(f"PASS ADD Test: All {total} test cases passed.")
    return res, total


def get_mul_test_cases_failed(width: int, rm: str) -> list:
    """Returns a list of known failing multiplication test cases."""
    mul16_test_cases = [
        ("1286", "8e9c", None, None, "rne"),  # Only for fp16
    ]
    return {16: mul16_test_cases, 32: [], 64: []}[width]


def get_mul_test_cases(width: int, rm: str, random_count: int) -> list:
    """Generate a list of test cases for fp_mul for a given width."""
    special_names = [
        "+zero",
        "-zero",
        "+inf",
        "-inf",
        "+qnan",
        "-qnan",
        "+snan",
        "-snan",
    ]
    special_values = [get_special_fp_hex(width, name) for name in special_names]

    # Width-specific tables of normal and denormal values for multiplication
    normal_denormal_vals = {
        16: [
            "3c00",  # 1.0
            "c000",  # -2.0
            "4000",  # 2.0
            "4200",  # 3.0
            "3800",  # 0.5
            "3400",  # 0.25
            "d6b8",  # Representative normal
            "8c61",  # Representative normal
            "06f3",  # Denormal
            "0e82",  # Denormal
            "03ff",  # Max denormal
            "0001",  # Min denormal
        ],
        32: [
            "3f800000",  # 1.0
            "c0000000",  # -2.0
            "40000000",  # 2.0
            "3f000000",  # 0.5
            "007fffff",  # Max denormal
            "00000001",  # Min denormal
        ],
        64: [
            "3ff0000000000000",  # 1.0
            "c000000000000000",  # -2.0
            "4000000000000000",  # 2.0
            "3fe0000000000000",  # 0.5
            "000fffffffffffff",  # Max denormal
            "0000000000000001",  # Min denormal
        ],
    }

    normal_values = normal_denormal_vals[width]

    mul_test_cases = []
    all_values = special_values + normal_values
    for a in all_values:
        for b in all_values:
            if a in special_values or b in special_values:
                mul_test_cases.append((a, b, None, None, rm))
                mul_test_cases.append((b, a, None, None, rm))

    # Determine exponent range for normal numbers
    exp_w = {16: 5, 32: 8, 64: 11}[width]
    mant_w = {16: 10, 32: 23, 64: 52}[width]
    max_exp = (1 << exp_w) - 2  # Max normal exponent

    # Generate random test cases with normal numbers
    for _ in range(random_count):
        a_val = (
            (random.randint(0, 1) << (width - 1))
            | (random.randint(1, max_exp) << mant_w)
            | (random.randint(0, (1 << mant_w) - 1))
        )
        b_val = (
            (random.randint(0, 1) << (width - 1))
            | (random.randint(1, max_exp) << mant_w)
            | (random.randint(0, (1 << mant_w) - 1))
        )
        mul_test_cases.append(
            (f"{a_val:0{width // 4}x}", f"{b_val:0{width // 4}x}", None, None, rm)
        )

    return mul_test_cases


def run_mul_tests(width: int, mul_test_cases: list) -> Tuple[int, int]:
    """Run a list of test cases for fp_mul."""
    total = 0
    res = 0

    for a, b, c_py, c_c, rm_str in mul_test_cases:
        print(f"\nTesting: fp{width}_mul(0x{a}, 0x{b}, {rm_str})")
        res += compare_fp_mul(a, b, width, c_py, c_c, rm_str)
        total += 1

    if res:
        print(f"FAIL MUL Test: {res} failed of {total} test cases.")
    else:
        print(f"PASS MUL Test: All {total} test cases passed.")
    return res, total


def tests(width: int = 16):
    """Runs all tests for a given width."""
    random_count = 10
    # random_count = 100
    # random_count = 1000
    res = 0
    rm_results = {}
    print(f"\n{'=' * 20} RUNNING TESTS FOR FP{width} {'=' * 20}")
    for rm in ["rne", "rtz", "rpi", "rni", "rna"]:
        # for rm in ["rpi"]:
        add_cases, mul_cases = [], []

        if width == 16:  # UVM cases are only for fp16 for now
            add_cases.extend(get_add_test_uvm_cases(width, rm))

        mul_cases.extend(get_mul_test_cases_failed(width, rm))

        add_cases.extend(get_add_test_cases(width, rm, random_count))
        mul_cases.extend(get_mul_test_cases(width, rm, random_count))

        res_add, total_add = run_add_tests(width, add_cases)
        res_mul, total_mul = run_mul_tests(width, mul_cases)
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

    return res

def main():
    """Main entry point."""
    compile_lib()
    res = 0
    # TODO: (now) for width in [16, 32, 64]:
    for width in [16]:
        res += tests(width)

    rc = min(res, 255)  # Limit the return code to 255 for Posix compatibility.
    return rc
    
if __name__ == "__main__":
    exit(main())
