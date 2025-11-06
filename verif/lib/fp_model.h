#ifndef FP_CLASSIFY_H
#define FP_CLASSIFY_H

#include <stdint.h>

// Helper union for type-punning between float and its bit representation
typedef union {
    float    f;
    uint32_t u;
} float_conv;

// Helper union for type-punning between double and its bit representation
typedef union {
    double   d;
    uint64_t u;
} double_conv;

// Rounding modes matching the Python model and SystemVerilog `grs_round_e` enum
#define RNE 0  // Round to Nearest, Ties to Even
#define RTZ 1  // Round Towards Zero
#define RPI 2  // Round Towards Positive Infinity
#define RNI 3  // Round Towards Negative Infinity
#define RNA 4  // Round to Nearest, Ties Away from Zero


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
} fp_classify_outputs_s;

// --- Arbitrary-Precision Integer Type for GRS Rounding ---
// Maximum precision bits supported by the custom integer type.
// This allows for mantissas up to 2048 bits wide.
#define MAX_AP_BITS 256
#define NUM_AP_WORDS ((MAX_AP_BITS + 63) / 64)

// Custom arbitrary-precision unsigned integer type
// Using __attribute__((packed)) to ensure no padding between array elements,
// making it a contiguous block of bits.
typedef struct __attribute__((packed)) {
    uint64_t parts[NUM_AP_WORDS];
} uint_ap_t;

// Helper function to initialize uint_ap_t to zero
static inline void uint_ap_set_zero(uint_ap_t *val) {
    for (int i = 0; i < NUM_AP_WORDS; ++i) {
        val->parts[i] = 0ULL;
    }
}

// Helper function to convert a uint64_t to uint_ap_t
static inline uint_ap_t uint_ap_from_uint64(uint64_t u64_val) {
    uint_ap_t res;
    uint_ap_set_zero(&res);
    res.parts[0] = u64_val;
    return res;
}

// Helper function to get a specific bit from uint_ap_t
// Returns 1 if the bit is set, 0 otherwise.
static inline int uint_ap_get_bit(uint_ap_t val, int bit_idx) {
    if (bit_idx < 0 || bit_idx >= MAX_AP_BITS) {
        // Accessing out of bounds should ideally be prevented by caller logic.
        // For safety, return 0 for out-of-bounds bits.
        return 0;
    }
    int word_idx = bit_idx / 64;
    int bit_in_word_idx = bit_idx % 64;
    return (val.parts[word_idx] >> bit_in_word_idx) & 1ULL;
}

// Helper function to check if any bit is set within the range [0, max_bit_idx] (inclusive).
// This is used for the 'sticky' bit calculation.
static inline int uint_ap_is_any_bit_set_up_to(uint_ap_t val, int max_bit_idx) {
    if (max_bit_idx < 0) { // No bits to check (e.g., shift_amount < 3)
        return 0;
    }
    // Cap max_bit_idx to prevent reading beyond the defined MAX_AP_BITS
    if (max_bit_idx >= MAX_AP_BITS) {
        max_bit_idx = MAX_AP_BITS - 1;
    }

    for (int i = 0; i <= max_bit_idx / 64; ++i) {
        uint64_t word_to_check = val.parts[i];
        if (i * 64 + 63 > max_bit_idx) { // This is the last partial word to check
            uint64_t mask = (1ULL << (max_bit_idx % 64 + 1)) - 1;
            word_to_check &= mask;
        }
        if (word_to_check != 0) {
            return 1; // Found a set bit
        }
    }
    return 0; // No set bits found in the range
}

#endif // FP_CLASSIFY_H