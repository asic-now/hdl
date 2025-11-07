// verif/lib/fp32_model.c
//
// This C code provides a "golden" reference model for 32-bit floating-point
// operations. The IEEE 754 single-precision format is equivalent to the C 'float'
// type on most modern platforms. These functions use type-punning to convert
// between the bit-level representation (uint32_t) and the native float type,
// then use the CPU's trusted FPU for the arithmetic.

#include <stdint.h>
#include <math.h>

// Standard DPI-C inclusion for simulator integration
#include "svdpi.h"

#include "fp_model.h"

// Converts a 32-bit integer representation to a C float
static float u32_to_float(uint32_t u) {
    float_conv conv;
    conv.u = u;
    return conv.f;
}

// Converts a C float to its 32-bit integer representation
static uint32_t float_to_u32(float f, const int rm) {
    // TODO: Implement rounding modes
    float_conv conv;
    conv.f = f;

    // Canonicalize NaN: If the result is NaN, return a standard quiet NaN.
    // This prevents mismatches due to different NaN payloads.
    if (isnan(f)) {
        // Standard qNaN representation (sign bit 0, exp all 1s, MSB of mantissa 1)
        return 0x7FC00000;
    }
    return conv.u;
}

// The exported DPI-C function that will be called from SystemVerilog
uint32_t c_fp32_add(uint32_t a, uint32_t b, const int rm) {
    float fa = u32_to_float(a);
    float fb = u32_to_float(b);
    float fresult = fa + fb;
    return float_to_u32(fresult, rm);
}

// Multiply two fp32 numbers
uint32_t c_fp32_mul(uint32_t a, uint32_t b, const int rm) {
    float fa = u32_to_float(a);
    float fb = u32_to_float(b);
    return float_to_u32(fa * fb, rm);
}

// Divide two fp32 numbers
uint32_t c_fp32_div(uint32_t a, uint32_t b, const int rm) {
    float fa = u32_to_float(a);
    float fb = u32_to_float(b);
    return float_to_u32(fa / fb, rm);
}

// Fused multiply-add
uint32_t c_fp32_mul_add(uint32_t a, uint32_t b, uint32_t c, const int rm) {
    float fa = u32_to_float(a);
    float fb = u32_to_float(b);
    float fc = u32_to_float(c);
    return float_to_u32(fmaf(fa, fb, fc), rm);
}

// Square root
uint32_t c_fp32_sqrt(uint32_t a, const int rm) {
    float fa = u32_to_float(a);
    return float_to_u32(sqrtf(fa), rm);
}
