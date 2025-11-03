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

#endif // FP_CLASSIFY_H