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

// Converts a 32-bit single-precision float to a 16-bit half-precision float, RNE mode
static uint16_t float_to_fp16_works_for_add(float f) {
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
        // Propagate mantissa to create a qNaN.
        // The MSB of the mantissa is set to 1 to indicate a qNaN.
        half_mant |= 0x200;
        return (sign << 15) | (half_exp << 10) | half_mant;
    }

    return (sign << 15) | (half_exp << 10) | half_mant;
}

static uint16_t double_to_fp16(double d, const int rm) {
    double_conv conv;
    conv.d = d;
    uint64_t x = conv.u;

    uint16_t sign_bit = (x >> 48) & 0x8000;
    int32_t  exp_64   = (x >> 52) & 0x7ff;
    uint64_t mant_64  = x & 0x000FFFFFFFFFFFFFULL;

    if (exp_64 == 0x7ff) { // NaN or Infinity
        uint16_t mant_16 = (mant_64 != 0) ? 0x0200 : 0; // Set qNaN bit if mantissa is non-zero
        return sign_bit | 0x7c00 | mant_16;
    }

    // Re-bias exponent from float64 to float16
    int32_t exp_16 = exp_64 - 1023 + 15;

    if (exp_16 >= 0x1f) { // Overflow
        if (rm == RNI) return 0xfbff; // Max normal neg number
        if (rm == RTZ && sign_bit) return 0xfbff; // Max normal neg number
        return sign_bit | 0x7c00; // Infinity
    }

    if (exp_16 <= 0) { // Underflow to denormalized or zero
        if (exp_16 < -10) { // Result is too small, flush to zero
            if (rm == RPI && !sign_bit) return 0x0001; // Smallest denormal
            if (rm == RNI && sign_bit) return 0x8001; // Smallest denormal
            return sign_bit;
        }
        // Create denormalized value
        uint64_t mant = (mant_64 | (1ULL << 52)) >> (1 - exp_16);
        uint64_t lsb     = (mant >> 42) & 1;
        uint64_t guard   = (mant >> 41) & 1;
        uint64_t sticky  = (mant & ((1ULL << 41) - 1)) != 0;
        uint16_t mant_16 = mant >> 42;

        if ((rm == RNE && guard && (sticky || lsb)) ||
            (rm == RNA && guard) ||
            (rm == RPI && !sign_bit && (guard || sticky)) ||
            (rm == RNI && sign_bit && (guard || sticky))) {
            mant_16++;
        }
        return sign_bit | mant_16;
    }

    // Normalized number
    uint64_t lsb    = (mant_64 >> 42) & 1;
    uint64_t guard  = (mant_64 >> 41) & 1;
    uint64_t sticky = (mant_64 & ((1ULL << 41) - 1)) != 0;
    uint16_t mant_16 = mant_64 >> 42;

    int round_up = 0;
    switch (rm) {
        case RNE: if (guard && (sticky || lsb)) round_up = 1; break;
        case RTZ: break;
        case RPI: if (!sign_bit && (guard || sticky)) round_up = 1; break;
        case RNI: if (sign_bit && (guard || sticky)) round_up = 1; break;
        case RNA: if (guard) round_up = 1; break;
    }

    if (round_up) {
        mant_16++;
        if (mant_16 >= 0x0400) { // Mantissa overflow
            mant_16 = 0;
            exp_16++;
            if (exp_16 >= 0x1f) { // Exponent overflow to infinity
                return sign_bit | 0x7c00;
            }
        }
    }

    return sign_bit | (exp_16 << 10) | mant_16;
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

// C model function to be exported
void c_fp16_classify(const uint16_t in, fp_classify_outputs_s* out) {
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
    *out = (fp_classify_outputs_s){0};

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
uint16_t c_fp16_add32(uint16_t a, uint16_t b, const int rm) {
    float fa = fp16_to_float(a);
    float fb = fp16_to_float(b);
    float fresult = fa + fb;
    return float_to_fp16(fresult, rm);
}

// The exported DPI-C function that will be called from SystemVerilog
uint16_t c_fp16_add(uint16_t a, uint16_t b, const int rm) {
    double da = (double)fp16_to_float(a);
    double db = (double)fp16_to_float(b);
    double dresult = da + db;
    return double_to_fp16(dresult, rm);
}

// Multiply two fp16 numbers: c = a * b
uint16_t c_fp16_mul(uint16_t a, uint16_t b, const int rm) {
    float fa = fp16_to_float(a);
    float fb = fp16_to_float(b);
    float fc = fa * fb;
    return float_to_fp16(fc, rm);
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
