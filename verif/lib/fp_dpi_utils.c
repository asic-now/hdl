// verif/lib/fp_dpi_utils.c
// DPI-C utility functions for converting SystemVerilog 'real' to floating-point bit patterns.

#include <stdint.h>
#include <math.h> // For sqrtf, etc. if needed, but not for bit conversions
#include "svdpi.h"

// Helper union for type-punning between double and uint64_t
typedef union {
    double d;
    uint64_t u;
} double_to_bits_conv;

// Helper union for type-punning between float and uint32_t
typedef union {
    float f;
    uint32_t u;
} float_to_bits_conv;

// DPI-C function to convert a SystemVerilog 'real' (double) to its 64-bit integer bit pattern.
// extern "C"
uint64_t c_real_to_fp64_bits(double val) {
    double_to_bits_conv conv;
    conv.d = val;
    return conv.u;
}

// DPI-C function to convert a SystemVerilog 'real' (double) to its 32-bit single-precision float bit pattern.
// This performs a double-to-float conversion, which might lose precision.
// SystemVerilog's $realtobits does this directly, so this function is provided for completeness
// but fp_pkg_utils.sv will use the built-in $realtobits for 32-bit.
// extern "C"
uint32_t c_real_to_fp32_bits(double val) {
    float_to_bits_conv conv;
    conv.f = (float)val; // Cast double to float
    return conv.u;
}

// DPI-C function to convert a SystemVerilog 'real' (double) to its 16-bit half-precision float bit pattern.
// This is a simplified conversion and might not handle all edge cases (e.g., denormals, rounding modes)
// as robustly as a dedicated FP16 library. It converts real -> float -> fp16.
// extern "C"
uint16_t c_real_to_fp16_bits(double val) {
    float_to_bits_conv f_conv;
    f_conv.f = (float)val; // Convert double to single precision first

    uint32_t x = f_conv.u;

    uint32_t sign = (x >> 31) & 1;
    uint32_t exp  = (x >> 23) & 0xff;
    uint32_t mant = x & 0x7fffff;

    uint16_t half_exp;
    uint16_t half_mant;

    if (exp == 255) { // Inf or NaN
        half_exp = 31;
        half_mant = mant >> 13;
        if (mant != 0) { // NaN
            half_mant |= 0x200; // Set MSB of mantissa for QNaN
        }
    } else if (exp > 127 + 15) { // Overflow to infinity
        half_exp = 31;
        half_mant = 0;
    } else if (exp < 127 - 14) { // Underflow to zero or denormal
        half_exp = 0;
        half_mant = 0;
    } else { // Normalized
        half_exp = exp - 127 + 15;
        half_mant = mant >> 13;
    }

    return (sign << 15) | (half_exp << 10) | half_mant;
}