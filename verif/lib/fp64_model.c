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
static uint64_t double_to_u64(double d) {
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

// C model function to be exported
void c_fp64_classify(const uint64_t in, fp_classify_outputs_s* out) {
    // Unpack the 64-bit input
    uint8_t  sign = (in >> 63) & 0x1;
    uint16_t exp  = (in >> 52) & 0x7FF;
    uint64_t mant = in & 0xFFFFFFFFFFFFF;

    // Intermediate checks based on IEEE 754 for FP64
    int exp_is_all_ones  = (exp == 0x7FF);
    int exp_is_all_zeros = (exp == 0x00);
    int mant_is_zero     = (mant == 0x0);

    int is_nan      = exp_is_all_ones && !mant_is_zero;
    int is_inf      = exp_is_all_ones && mant_is_zero;
    int is_zero     = exp_is_all_zeros && mant_is_zero;
    int is_denormal = exp_is_all_zeros && !mant_is_zero;
    int is_normal   = !exp_is_all_ones && !exp_is_all_zeros;

    // Initialize all outputs to 0
    *out = (fp_classify_outputs_s){0};

    // Determine NaN type
    if (is_nan) {
        if (mant & 0x8000000000000) { // MSB of mantissa for FP64
            out->is_qnan = 1;
        } else {
            out->is_snan = 1;
        }
    }

    // Set final outputs based on sign
    if (sign) { // Negative
        if (is_inf)      out->is_neg_inf      = 1;
        if (is_normal)   out->is_neg_normal   = 1;
        if (is_denormal) out->is_neg_denormal = 1;
        if (is_zero)     out->is_neg_zero     = 1;
    } else { // Positive
        if (is_inf)      out->is_pos_inf      = 1;
        if (is_normal)   out->is_pos_normal   = 1;
        if (is_denormal) out->is_pos_denormal = 1;
        if (is_zero)     out->is_pos_zero     = 1;
    }
}

// The exported DPI-C function that will be called from SystemVerilog
uint64_t c_fp64_add(uint64_t a, uint64_t b) {
    double da = u64_to_double(a);
    double db = u64_to_double(b);
    double dresult = da + db;
    return double_to_u64(dresult);
}

// Multiply two fp64 numbers
uint64_t c_fp64_mul(uint64_t a, uint64_t b) {
    double da = u64_to_double(a);
    double db = u64_to_double(b);
    return double_to_u64(da * db);
}

// Divide two fp64 numbers
uint64_t c_fp64_div(uint64_t a, uint64_t b) {
    double da = u64_to_double(a);
    double db = u64_to_double(b);
    return double_to_u64(da / db);
}

// Fused multiply-add
uint64_t c_fp64_mul_add(uint64_t a, uint64_t b, uint64_t c) {
    double da = u64_to_double(a);
    double db = u64_to_double(b);
    double dc = u64_to_double(c);
    return double_to_u64(fma(da, db, dc));
}

// Square root
uint64_t c_fp64_sqrt(uint64_t a) {
    double da = u64_to_double(a);
    return double_to_u64(sqrt(da));
}
