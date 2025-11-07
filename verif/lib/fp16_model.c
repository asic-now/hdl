// verif/lib/fp16_model.c
//
// This C code provides a "golden" reference model for 16-bit floating-point
// operations. It works by converting the 16-bit half-precision format to the
// standard 32-bit C 'float' type, performing the operation using the CPU's
// trusted IEEE 754 hardware, and converting the result back.
//

#include <stdint.h>
#include <math.h>

// Standard DPI-C inclusion for simulator integration
#include "svdpi.h"

#include "fp_model.h"

// Converts a 16-bit half-precision float to a 32-bit single-precision float
static float fp16_to_float(uint16_t h) {
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

static uint16_t float_to_fp16(float f, const int rm) {
    float_conv conv;
    conv.f = f;
    uint32_t x = conv.u;

    uint16_t sign_bit = (x >> 16) & 0x8000;
    int32_t  exp_32   = (x >> 23) & 0xff;
    uint32_t mant_32  = x & 0x7fffff;

    if (exp_32 == 0xff) { // NaN or Infinity
        uint16_t mant_16 = (mant_32 != 0) ? 0x0200 : 0; // Set qNaN bit if mantissa is non-zero
        return sign_bit | 0x7c00 | mant_16;
    }

    // Re-bias exponent from float32 to float16
    int32_t exp_16 = exp_32 - 127 + 15;

    if (exp_16 >= 0x1f) { // Overflow
        if (rm == RNI) {
            return 0xfbff; // Max normal neg number
        }
        if (rm == RTZ && sign_bit) {
            return 0xfbff; // Max normal neg number
        }
        return sign_bit | 0x7c00; // Infinity
    }

    if (exp_16 <= 0) { // Underflow to denormalized or zero
        if (exp_16 < -10) { // Result is too small, flush to zero
            if (rm == RPI && !sign_bit) return 0x0001; // Smallest denormal
            if (rm == RNI && sign_bit) return 0x8001; // Smallest denormal
            return sign_bit;
        }
        // Create denormalized value
        uint32_t mant = (mant_32 | 0x800000) >> (1 - exp_16);
        uint32_t lsb     =  mant & 0x2000;
        uint32_t guard   =  mant & 0x1000;
        // uint32_t r       =  mant & 0x1000;
        uint32_t sticky  = (mant & 0x0fff) != 0;
        uint16_t mant_16 =  mant >> 13;

        if ((rm == RNE && guard && (sticky || lsb)) ||
            (rm == RNA && guard) ||
            (rm == RPI && !sign_bit && (guard || sticky)) ||
            (rm == RNI && sign_bit && (guard || sticky))) {
            mant_16++;
        }
        return sign_bit | mant_16;
    }

    // Normalized number
    uint32_t lsb    =  mant_32 & 0x2000;
    uint32_t guard  =  mant_32 & 0x1000;
    // uint32_t r      =  mant_32 & 0x0800;
    uint32_t sticky = (mant_32 & 0x0fff) != 0;
    uint16_t mant_16 = mant_32 >> 13;

    int round_up = 0;
    switch (rm) {
        case RNE: // Round to Nearest, Ties to Even
            if (guard && (sticky || lsb)) round_up = 1;
            break;
        case RTZ: // Round Towards Zero
            // No action, truncation is default
            break;
        case RPI: // Round Towards Positive Infinity
            if (!sign_bit && (guard || sticky)) round_up = 1;
            break;
        case RNI: // Round Towards Negative Infinity
            if (sign_bit && (guard || sticky)) round_up = 1;
            break;
        case RNA: // Round to Nearest, Ties Away from Zero
            if (guard) round_up = 1;
            break;
    }

    if (round_up) {
        mant_16++;
        if (mant_16 >= 0x0400) { // Mantissa overflow
            mant_16 = mant_16 >> 1;
            exp_16++;
            if (exp_16 >= 0x1f) { // Exponent overflow to infinity
                return sign_bit | 0x7c00;
            }
        }
    }

    return sign_bit | (exp_16 << 10) | mant_16;
}

// Divide two fp16 numbers: c = a / b
uint16_t c_fp16_div(uint16_t a, uint16_t b, const int rm) {
    float fa = fp16_to_float(a);
    float fb = fp16_to_float(b);
    float fc = fa / fb;
    return float_to_fp16(fc, rm);
}

// Fused multiply-add: c = a * b + c
uint16_t c_fp16_mul_add(uint16_t a, uint16_t b, uint16_t c, const int rm) {
    float fa = fp16_to_float(a);
    float fb = fp16_to_float(b);
    float fc = fp16_to_float(c);
    return float_to_fp16(fa * fb + fc, rm);
}

// Fused multiply-subtract: c = a * b - c
uint16_t c_fp16_mul_sub(uint16_t a, uint16_t b, uint16_t c, const int rm) {
    float fa = fp16_to_float(a);
    float fb = fp16_to_float(b);
    float fc = fp16_to_float(c);
    return float_to_fp16(fa * fb - fc, rm);
}

// Reciprocal: c = 1.0 / a
uint16_t c_fp16_recip(uint16_t a, const int rm) {
    float fa = fp16_to_float(a);
    float fc = 1.0f / fa;
    return float_to_fp16(fc, rm);
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
uint16_t c_fp16_invsqrt(uint16_t a, const int rm) {
    float fa = fp16_to_float(a);
    float fc = 1.0f / sqrtf(fa);
    return float_to_fp16(fc, rm);
}

// Square root: c = sqrt(a)
uint16_t c_fp16_sqrt(uint16_t a, const int rm) {
    float fa = fp16_to_float(a);
    float fc = sqrtf(fa);
    return float_to_fp16(fc, rm);
}
