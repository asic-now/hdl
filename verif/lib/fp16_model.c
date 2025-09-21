// verif/lib/fp16_model.c
#include <stdint.h>
#include <math.h>

// Standard DPI-C inclusion for simulator integration
#include "svdpi.h"

//
// This C code provides a "golden" reference model for 16-bit floating-point
// operations. It works by converting the 16-bit half-precision format to the
// standard 32-bit C 'float' type, performing the operation using the CPU's
// trusted IEEE 754 hardware, and converting the result back.
//

// Helper union for type-punning between float and its bit representation
typedef union {
    float f;
    uint32_t u;
} float_conv;

// #define float_to_fp16 float_to_fp16_1
#define float_to_fp16 float_to_fp16_1a
#define fp16_to_float fp16_to_float_1

// #define float_to_fp16 float_to_fp16_2
// #define fp16_to_float fp16_to_float_2

// Converts a 16-bit half-precision float to a 32-bit single-precision float
static float fp16_to_float_1(uint16_t h) {
    uint16_t sign = (h >> 15) & 0x0001;
    uint16_t exp  = (h >> 10) & 0x001f;
    uint16_t mant =  h        & 0x03ff;
    float_conv f;

    if (exp == 0) { // Denormalized or zero
        if (mant == 0) { // Zero
            f.u = sign << 31;
        } else { // Denormalized
            while (!(mant & 0x0400)) {
                mant <<= 1;
                exp--;
            }
            exp++;
            mant &= ~0x0400;
            f.u = (sign << 31) | ((exp - 15 + 127) << 23) | (mant << 13);
        }
    } else if (exp == 31) { // Infinity or NaN
        if (mant == 0) { // Infinity
            f.u = (sign << 31) | 0x7f800000;
        } else { // NaN
            f.u = (sign << 31) | 0x7f800000 | (mant << 13);
        }
    } else { // Normalized
        f.u = (sign << 31) | ((exp - 15 + 127) << 23) | (mant << 13);
    }
    return f.f;
}

// Converts a 32-bit single-precision float to a 16-bit half-precision float
static uint16_t float_to_fp16_1(float f) {
    float_conv fc;
    fc.f = f;
    uint32_t x = fc.u;

    uint16_t sign = (x >> 16) & 0x8000;
    int32_t exp   = (x >> 23) & 0xff;
    int32_t mant  = x & 0x7fffff;

    if (exp == 255) { // Inf or NaN
        return sign | 0x7c00 | (mant ? 0x0200 : 0); // Propagate NaN
    }
    
    exp = exp - 127 + 15;

    if (exp >= 31) { // Overflow
        return sign | 0x7c00;
    }
    if (exp <= 0) { // Underflow
        // Handle denormalization
        if (exp < -10) {
            return sign;
        }
        mant = (mant | 0x800000) >> (1 - exp);
        return sign | (mant >> 13);
    }
    return sign | (exp << 10) | (mant >> 13);
}
static uint16_t float_to_fp16_1a(float f) {
    float_conv conv;
    conv.f = f;
    uint32_t x = conv.u;

    uint32_t sign = (x >> 31) & 1;
    uint32_t exp  = (x >> 23) & 0xff;
    uint32_t mant = x & 0x7fffff;

    uint16_t half_exp;
    if (exp == 255) { // Inf or NaN
        half_exp = 31;
    } else if (exp > 127 + 15) { // Overflow
        half_exp = 31;
    } else if (exp < 127 - 14) { // Underflow to zero
        half_exp = 0;
    } else {
        half_exp = exp - 127 + 15;
    }

    uint16_t half_mant = mant >> 13;

    if (exp == 255 && mant != 0) { // NaN
        return (sign << 15) | (half_exp << 10) | 0x200; // Return qNaN
    }

    return (sign << 15) | (half_exp << 10) | half_mant;
}
// Converts a 32-bit single-precision float to a 16-bit half-precision float
// (Based on a public domain implementation by Fabian Giesen, with corrections)
static uint16_t float_to_fp16_1b(float f) {
    float_conv conv;
    conv.f = f;
    uint32_t x = conv.u;

    uint32_t sign = (x >> 31) & 1;
    int32_t  exp  = (x >> 23) & 0xff;
    uint32_t mant = x & 0x7fffff;

    // Handle Inf or NaN
    if (exp == 255) {
        return (sign << 15) | 0x7c00 | (mant ? 0x200 : 0); // NaN or Inf
    }
    
    // Re-bias the exponent from float32 to float16
    exp = exp - 127 + 15;

    // Handle overflow, underflow, and denormalized cases
    if (exp >= 31) { // Overflow
        return (sign << 15) | 0x7c00;
    }
    
    if (exp <= 0) { // Underflow or becomes denormalized
        if (exp < -10) { // Underflows completely to zero
            return sign << 15;
        }
        // The number is denormalized. Re-insert the implicit 1 bit and shift.
        mant = (mant | 0x800000) >> (1 - exp);
        // Truncate and return
        return (sign << 15) | (mant >> 13);
    }

    // Normal number
    return (sign << 15) | (exp << 10) | (mant >> 13);
}

// Function to convert fp16 binary to float
float fp16_to_float_2(uint16_t h) {
    uint16_t sign = (h >> 15) & 0x0001;
    uint16_t exp = (h >> 10) & 0x001F;
    uint16_t frac = h & 0x03FF;

    if (exp == 0) {
        // Subnormal or zero
        if (frac == 0) {
            // Zero
            return sign ? -0.0f : 0.0f;
        } else {
            // Subnormal
            float mantissa = frac / 1024.0f;
            float val = ldexpf(mantissa, -14);
            return sign ? -val : val;
        }
    } else if (exp == 31) {
        // Inf or NaN
        if (frac == 0) {
            return sign ? -INFINITY : INFINITY;
        } else {
            return NAN;
        }
    } else {
        // Normalized
        float mantissa = 1.0f + frac / 1024.0f;
        int e = exp - 15;
        float val = ldexpf(mantissa, e);
        return sign ? -val : val;
    }
}

// Function to convert float to fp16 binary
uint16_t float_to_fp16_2(float f) {
    if (isnan(f)) return 0x7E00; // qNaN
    if (isinf(f)) return (signbit(f) ? 0xFC00 : 0x7C00);
    if (f == 0.0f) return (signbit(f) ? 0x8000 : 0x0000);

    int sign = 0;
    if (f < 0) {
        sign = 0x8000;
        f = -f;
    }

    int exp;
    float mantissa = frexpf(f, &exp);

    // Normalize mantissa to [1, 2)
    mantissa *= 2.0f;
    exp -= 1;

    int16_t exp_half = exp + 15;

    if (exp_half >= 31) {
        // Overflow to infinity
        return sign | 0x7C00;
    } else if (exp_half <= 0) {
        // Subnormal number or zero
        if (exp_half < -10) {
            // Too small becomes zero
            return sign;
        }
        mantissa = ldexpf(mantissa, exp_half - 1);
        uint16_t frac = (uint16_t)(mantissa * 1024.0f + 0.5f);
        return sign | frac;
    } else {
        uint16_t frac = (uint16_t)((mantissa - 1.0f) * 1024.0f + 0.5f);
        return sign | (exp_half << 10) | frac;
    }
}

// Define the output struct using C bit-fields to ensure a memory layout
// identical to the SystemVerilog 'struct packed'. The total size is 10 bits.
// The order is reversed from the SV declaration to match how C compilers
// typically pack bit-fields (from LSB upwards in memory).
typedef struct {
    unsigned int is_pos_inf      : 1; // Corresponds to bit 0 in the SV packed struct
    unsigned int is_pos_normal   : 1;
    unsigned int is_pos_denormal : 1;
    unsigned int is_pos_zero     : 1;
    unsigned int is_neg_zero     : 1;
    unsigned int is_neg_denormal : 1;
    unsigned int is_neg_normal   : 1;
    unsigned int is_neg_inf      : 1;
    unsigned int is_qnan         : 1;
    unsigned int is_snan         : 1; // Corresponds to bit 9
} fp16_classify_outputs_s;

// C model function to be exported
void c_fp16_classify(const uint16_t in, fp16_classify_outputs_s* out) {
    // Unpack the 16-bit input
    uint8_t  sign = (in >> 15) & 0x1;
    uint8_t  exp  = (in >> 10) & 0x1F;
    uint16_t mant = in & 0x3FF;

    // Intermediate checks based on IEEE 754 for FP16
    int exp_is_all_ones  = (exp == 0x1F);
    int exp_is_all_zeros = (exp == 0x00);
    int mant_is_zero     = (mant == 0x000);

    int is_nan      = exp_is_all_ones && !mant_is_zero;
    int is_inf      = exp_is_all_ones && mant_is_zero;
    int is_zero     = exp_is_all_zeros && mant_is_zero;
    int is_denormal = exp_is_all_zeros && !mant_is_zero;
    int is_normal   = !exp_is_all_ones && !exp_is_all_zeros;

    // Initialize all outputs to 0
    *out = (fp16_classify_outputs_s){0};

    // Determine NaN type
    if (is_nan) {
        if (mant & 0x200) { // MSB of mantissa for FP16
            out->is_qnan = 1;
        } else {
            out->is_snan = 1;
        }
    }

    // Set final outputs based on sign
    if (sign) { // Negative
        if (is_inf)      out->is_neg_inf = 1;
        if (is_normal)   out->is_neg_normal = 1;
        if (is_denormal) out->is_neg_denormal = 1;
        if (is_zero)     out->is_neg_zero = 1;
    } else { // Positive
        if (is_inf)      out->is_pos_inf = 1;
        if (is_normal)   out->is_pos_normal = 1;
        if (is_denormal) out->is_pos_denormal = 1;
        if (is_zero)     out->is_pos_zero = 1;
    }
}

// The exported DPI-C function that will be called from SystemVerilog
// extern "C"
uint16_t c_fp16_add(uint16_t a, uint16_t b) {
    float fa = fp16_to_float(a);
    float fb = fp16_to_float(b);
    float fresult = fa + fb;
    return float_to_fp16(fresult);
}

// Multiply two fp16 numbers: c = a * b
uint16_t c_fp16_mul(uint16_t a, uint16_t b) {
    float fa = fp16_to_float(a);
    float fb = fp16_to_float(b);
    float fc = fa * fb;
    return float_to_fp16(fc);
}

// Divide two fp16 numbers: c = a / b
uint16_t c_fp16_div(uint16_t a, uint16_t b) {
    float fa = fp16_to_float(a);
    float fb = fp16_to_float(b);
    float fc = fa / fb;
    return float_to_fp16(fc);
}

// Fused multiply-add: c = a * b + c
uint16_t c_fp16_mul_add(uint16_t a, uint16_t b, uint16_t c) {
    float fa = fp16_to_float(a);
    float fb = fp16_to_float(b);
    float fc = fp16_to_float(c);
    return float_to_fp16(fa * fb + fc);
}

// Fused multiply-subtract: c = a * b - c
uint16_t c_fp16_mul_sub(uint16_t a, uint16_t b, uint16_t c) {
    float fa = fp16_to_float(a);
    float fb = fp16_to_float(b);
    float fc = fp16_to_float(c);
    return float_to_fp16(fa * fb - fc);
}

// Reciprocal: c = 1.0 / a
uint16_t c_fp16_recip(uint16_t a) {
    float fa = fp16_to_float(a);
    float fc = 1.0f / fa;
    return float_to_fp16(fc);
}

// Compare: -1 if a < b, 0 if a == b, 1 if a > b
int c_fp16_cmp(uint16_t a, uint16_t b) {
    float fa = fp16_to_float(a);
    float fb = fp16_to_float(b);
    if (fa < fb) return -1;
    if (fa > fb) return 1;
    return 0;
}

// Inverse square root: c = 1.0 / sqrt(a)
uint16_t c_fp16_invsqrt(uint16_t a) {
    float fa = fp16_to_float(a);
    float fc = 1.0f / sqrtf(fa);
    return float_to_fp16(fc);
}

// Square root: c = sqrt(a)
uint16_t c_fp16_sqrt(uint16_t a) {
    float fa = fp16_to_float(a);
    float fc = sqrtf(fa);
    return float_to_fp16(fc);
}
