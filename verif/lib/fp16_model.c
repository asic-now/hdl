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

// Helper function for GRS rounding logic, mirroring Python's grs_round
static int grs_round_c(uint_ap_t value_in, int sign_in, int mode, int input_width, int output_width) {
    int shift_amount = input_width - output_width;

    if (shift_amount <= 0) {
        return 0;
    }

    // LSB of the part that will be kept (bit at position 'shift_amount')
    int lsb = uint_ap_get_bit(value_in, shift_amount);

    // Guard bit: The most significant bit of the truncated portion (bit at position 'shift_amount - 1')
    int g = (shift_amount >= 1) ? uint_ap_get_bit(value_in, shift_amount - 1) : 0;

    // Round bit: The bit immediately to the right of the Guard bit (bit at position 'shift_amount - 2')
    int r = (shift_amount >= 2) ? uint_ap_get_bit(value_in, shift_amount - 2) : 0;

    // Sticky bit: The logical OR of all bits to the right of the Round bit.
    int s = 0;
    if (shift_amount >= 3) {
        // Check if any bit from 0 to (shift_amount - 3) is set.
        s = uint_ap_is_any_bit_set_up_to(value_in, shift_amount - 3);
    }

    int inexact = g | r | s;
    int increment = 0;

    switch (mode) {
        case RNE: // Round to Nearest, Ties to Even
            increment = g & (r | s | lsb);
            break;
        case RTZ: // Round Towards Zero
            increment = 0;
            break;
        case RPI: // Round Towards Positive Infinity
            increment = (!sign_in) & inexact;
            break;
        case RNI: // Round Towards Negative Infinity
            increment = sign_in & inexact;
            break;
        case RNA: // Round to Nearest, Ties Away from Zero
            increment = g;
            break;
        default:
            increment = 0; // Default to RTZ for unknown modes
            break;
    }
    return increment;
}

// The exported DPI-C function that will be called from SystemVerilog
// This is a bit-accurate model of fp_add.v for fp16, with configurable intermediate precision.
uint16_t c_fp16_add_ex(uint16_t a_val, uint16_t b_val, const int rm, const int precision_bits) {
    // FP16 constants
    const int EXP_W = 5;
    const int MANT_W = 10;
    // const int EXP_BIAS = 15; // Not directly used in this bit-accurate logic

    // Unpack inputs
    int sign_a = (a_val >> 15) & 1;
    int exp_a = (a_val >> 10) & 0x1F;
    uint16_t mant_a = a_val & 0x3FF;

    int sign_b = (b_val >> 15) & 1;
    int exp_b = (b_val >> 10) & 0x1F;
    uint16_t mant_b = b_val & 0x3FF;

    // Handle special cases (NaN, Inf, Zero)
    int is_nan_a = (exp_a == 0x1F && mant_a != 0);
    int is_inf_a = (exp_a == 0x1F && mant_a == 0);
    int is_zero_a = (exp_a == 0x00 && mant_a == 0);

    int is_nan_b = (exp_b == 0x1F && mant_b != 0);
    int is_inf_b = (exp_b == 0x1F && mant_b == 0);
    int is_zero_b = (exp_b == 0x00 && mant_b == 0);

    if (is_nan_a || is_nan_b) {
        return 0x7E00; // Canonical qNaN
    }
    if (is_inf_a && is_inf_b && sign_a != sign_b) {
        return 0x7E00; // Inf - Inf = NaN
    }
    if (is_inf_a) {
        return a_val;
    }
    if (is_inf_b) {
        return b_val;
    }
    if (is_zero_a && is_zero_b) {
        // +0 + -0 = +0 (RNE), but -0 + -0 = -0
        return (sign_a && sign_b) ? 0x8000 : 0x0000;
    }
    if (is_zero_a) {
        return b_val;
    }
    if (is_zero_b) {
        return a_val;
    }

    // Add implicit bit (1 for normal, 0 for denormal)
    uint64_t full_mant_a = ((uint64_t)(exp_a != 0) << MANT_W) | mant_a;
    uint64_t full_mant_b = ((uint64_t)(exp_b != 0) << MANT_W) | mant_b;

    // Effective exponents (denormals have exp=1 for calculation)
    int eff_exp_a = (exp_a != 0) ? exp_a : 1;
    int eff_exp_b = (exp_b != 0) ? exp_b : 1;

    // Align mantissas
    int align_mant_w = MANT_W + 1 + precision_bits; // e.g., 10 + 1 + 32 = 43 for fp16
    uint64_t mant_a_aligned = full_mant_a << precision_bits;
    uint64_t mant_b_aligned = full_mant_b << precision_bits;

    int res_exp;
    int exp_diff = eff_exp_a - eff_exp_b;
    if (exp_diff > 0) {
        mant_b_aligned >>= exp_diff;
        res_exp = eff_exp_a;
    } else {
        mant_a_aligned >>= -exp_diff;
        res_exp = eff_exp_b;
    }

    // Add or Subtract
    int op_is_sub = sign_a != sign_b;
    uint64_t res_mant;
    int res_sign;

    if (op_is_sub) {
        if (mant_a_aligned >= mant_b_aligned) {
            res_mant = mant_a_aligned - mant_b_aligned;
            res_sign = sign_a;
        } else {
            res_mant = mant_b_aligned - mant_a_aligned;
            res_sign = sign_b; // Sign of the larger magnitude operand
        }
    } else {
        res_mant = mant_a_aligned + mant_b_aligned;
        res_sign = sign_a; // Sign is the same as operands
    }

    if (res_mant == 0) {
        // Result is exact zero. Handle signed zero for RNI mode if it was a subtraction.
        return (rm == RNI && op_is_sub) ? 0x8000 : 0x0000;
    }

    // Normalize
    int msb_pos = 0;
    if (res_mant > 0) {
        // Equivalent to Python's bit_length() - 1 for non-zero values
        // __builtin_clzll counts leading zeros for unsigned long long (64-bit)
        msb_pos = (sizeof(uint64_t) * 8 - 1) - __builtin_clzll(res_mant);
    }

    // Normalized position for implicit bit is at align_mant_w - 1
    int norm_pos = align_mant_w - 1;
    int shift = norm_pos - msb_pos;

    if (shift > 0) {
        res_mant <<= shift;
    } else {
        res_mant >>= -shift;
    }
    res_exp -= shift;

    // Rounding
    // The implicit bit is at align_mant_w-1, mantissa is below it.
    // We want to round to MANT_W bits.
    // The input to the rounder is the mantissa without the implicit bit.
    int rounder_input_width = align_mant_w - 1; // Bits from 0 to align_mant_w-2
    int rounder_output_width = MANT_W; // 10 bits for FP16

    // Extract the portion of res_mant that goes into the rounder
    // This is the mantissa *after* the implicit bit, extended by precision_bits
    uint64_t rounder_input = res_mant & ((1ULL << rounder_input_width) - 1);
    // Convert to arbitrary precision type for grs_round_c
    uint_ap_t rounder_input_ap = uint_ap_from_uint64(rounder_input);

    int increment = grs_round_c(rounder_input_ap, res_sign, rm, rounder_input_width, rounder_output_width);

    uint64_t rounded_mant_no_implicit = (rounder_input >> (rounder_input_width - rounder_output_width)) + increment;

    // Check for mantissa overflow from rounding
    if ((rounded_mant_no_implicit >> MANT_W) != 0) { // If bit MANT_W is set (i.e., 1 << MANT_W)
        res_exp += 1;
        rounded_mant_no_implicit >>= 1; // Shift right to keep MANT_W bits
    }

    uint16_t final_mant = rounded_mant_no_implicit & ((1 << MANT_W) - 1); // Extract MANT_W bits

    // Final checks for overflow/underflow
    uint16_t final_exp;
    if (res_exp >= 0x1F) { // Overflow to infinity
        final_exp = 0x1F;
        final_mant = 0;
    } else if (res_exp <= 0) { // Underflow to denormal or zero
        // Simplified: flush to zero. A full model would create denormals.
        // TODO: (when needed) Implement denormal values result
        final_exp = 0;
        final_mant = 0;
    } else {
        final_exp = res_exp;
    }

    // Pack final result
    uint16_t result_int = (res_sign << 15) | (final_exp << 10) | final_mant;
    return result_int;
}

// The exported DPI-C function that will be called from SystemVerilog
// This version uses float (32-bit) for intermediate calculations.
uint16_t c_fp16_add_float_intermediate(uint16_t a, uint16_t b, const int rm) {
    float fa = fp16_to_float(a);
    float fb = fp16_to_float(b);
    float fresult = fa + fb;
    return float_to_fp16(fresult, rm);
}

// The exported DPI-C function that will be called from SystemVerilog
// This version uses double (64-bit) for intermediate calculations.
uint16_t c_fp16_add_double_intermediate(uint16_t a, uint16_t b, const int rm) {
    // Convert fp16 to double, perform addition, then convert back to fp16
    double da = (double)fp16_to_float(a);
    double db = (double)fp16_to_float(b);
    double dresult = da + db;
    return double_to_fp16(dresult, rm);
}

// Default c_fp16_add to use the bit-accurate model with 32 precision bits
uint16_t c_fp16_add(uint16_t a, uint16_t b, const int rm) {
    return c_fp16_add_ex(a, b, rm, 32);
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
