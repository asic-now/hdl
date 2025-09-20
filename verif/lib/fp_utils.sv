// fp_utils.sv
//
// This file contains a package with utility classes and functions for
// floating-point verification, such as the canonicalizer.

`include "uvm_macros.svh"

`include "fp16_inc.vh"

package fp_utils_pkg;
    import uvm_pkg::*;

    // A utility class containing static helper functions for FP verification.
    class fp_utils;

        // Converts a 16-bit floating point number to a single, standard
        // representation for its class (e.g., all qNaNs become one pattern).
        static function logic [15:0] fp16_canonicalize(logic [15:0] val);
            logic       sign = val[15];
            logic [4:0] exp  = val[14:10];
            logic [9:0] mant = val[ 9: 0];

            logic is_nan      = (exp == 5'h1F) && (mant != 0);
            logic is_snan     = is_nan && (mant[9] == 0); // Signaling NaN
            // logic is_qnan     = is_nan && (mant[9] == 1); // Quiet NaN
            logic is_neg_zero = (val == `FP16_N_ZERO);
            
            // This commented out block keeps sNaN intact
            // if (is_snan) begin
            //     // Return a single, standard signaling NaN representation.
            //     // The sign bit is preserved.
            //     return {sign, 5'h1F, 10'b0000000001};
            // end else 
            if (is_nan) begin
                // Return a single, standard quiet NaN representation.
                // return {sign, 5'h1F, 10'b1000000001}; // The sign bit is preserved.
                return {1'b0, 5'h1F, 10'b1000000001}; // Clear the sign bit.
            end else if (is_neg_zero) begin
                // Canonical zero is +0.
                return `FP16_P_ZERO;
            end else begin
                // All other values (Inf, Normals, Denormals, +Zero) are
                // already in their canonical form.
                return val;
            end
        endfunction

    endclass

endpackage
