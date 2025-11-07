// verif/lib/fp64_model.c
//
// This C code provides a "golden" reference model for 64-bit floating-point
// operations. The IEEE 754 double-precision format is equivalent to the C 'double'
// type on most modern platforms. These functions use type-punning to convert
// between the bit-level representation (uint64_t) and the native double type,
// then use the CPU's trusted FPU for the arithmetic.

#include <stdint.h>
#include <math.h>

// Standard DPI-C inclusion for simulator integration
#include "svdpi.h"

#include "fp_model.h"

// Converts a 64-bit integer representation to a C double
static double u64_to_double(uint64_t u) {
    double_conv conv;
    conv.u = u;
    return conv.d;
}

// Converts a C double to its 64-bit integer representation
static uint64_t double_to_u64(double d, const int rm) {
    // TODO: Implement rounding modes
    double_conv conv;
    conv.d = d;

    // Canonicalize NaN: If the result is NaN, return a standard quiet NaN.
    // This prevents mismatches due to different NaN payloads.
    if (isnan(d)) {
        // Standard qNaN representation (sign bit 0, exp all 1s, MSB of mantissa 1)
        return 0x7FF8000000000000ULL;
    }
    return conv.u;
}

// Multiply two fp64 numbers
uint64_t c_fp64_mul(uint64_t a, uint64_t b, const int rm) {
    double da = u64_to_double(a);
    double db = u64_to_double(b);
    return double_to_u64(da * db, rm);
}

// Divide two fp64 numbers
uint64_t c_fp64_div(uint64_t a, uint64_t b, const int rm) {
    double da = u64_to_double(a);
    double db = u64_to_double(b);
    return double_to_u64(da / db, rm);
}

// Fused multiply-add
uint64_t c_fp64_mul_add(uint64_t a, uint64_t b, uint64_t c, const int rm) {
    double da = u64_to_double(a);
    double db = u64_to_double(b);
    double dc = u64_to_double(c);
    return double_to_u64(fma(da, db, dc), rm);
}

// Square root
uint64_t c_fp64_sqrt(uint64_t a, const int rm) {
    double da = u64_to_double(a);
    return double_to_u64(sqrt(da), rm);
}
