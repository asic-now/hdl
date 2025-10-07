// verif/lib/fp_utils.sv
//
// This file contains a package with utility classes and functions for
// floating-point verification, such as the canonicalizer.

`include "uvm_macros.svh"
import uvm_pkg::*;

`include "fp16_inc.vh"

// A parameterized utility class containing static helper functions for FP verification.
// This allows for type-safe, width-generic operations.
class fp_utils_t #(
    int WIDTH = 16,
    int EXP_W  = (WIDTH == 64) ? 11 : (WIDTH == 32) ?  8 : (WIDTH == 16) ?  5 : 0
);
    localparam MANT_W       = WIDTH - 1 - EXP_W;

    // Converts a floating point number to a single, standard representation
    // for its class (e.g., all qNaNs become one pattern).
    static function logic [WIDTH-1:0] canonicalize(logic [WIDTH-1:0] val);
        logic [EXP_W-1 :0] exp_max = '1; // in SystemVerilog sets all bits to 1
        logic [MANT_W-1:0] mant_zero = '0;

        logic              sign = val[WIDTH-1];
        logic [EXP_W-1 :0] exp  = val[WIDTH-2 : MANT_W];
        logic [MANT_W-1:0] mant = val[MANT_W-1 : 0];

        logic is_nan = (exp == exp_max) && (mant != mant_zero);

        // A negative zero has the sign bit set and all other bits clear.
        logic is_neg_zero = (val == {1'b1, {(WIDTH-1){1'b0}}});

        if (is_nan) begin
            // Return a single, standard quiet NaN representation.
            // The standard is to clear the sign bit and set the MSB of the mantissa.
            logic [MANT_W-1:0] qnan_mant = 1'b1 << (MANT_W - 1);
            return {1'b0, exp_max, qnan_mant};
        end else if (is_neg_zero) begin
            // Canonical zero is +0.
            return {WIDTH{1'b0}};
        end else begin
            // All other values (Inf, Normals, Denormals, +Zero) are
            // already in their canonical form.
            return val;
        end
    endfunction

endclass

// For convenience, provide a non-parameterized handles for the common types.
typedef fp_utils_t#(16) fp16_utils;
typedef fp_utils_t#(32) fp32_utils;
typedef fp_utils_t#(64) fp64_utils;
