// rtl/verilog/fp/fp_classify.v
//
// Verilog RTL for a parameterized floating-point classifier.
// This module identifies the category of a given floating-point number
// based on the IEEE 754 standard.
//
// Outputs are mutually exclusive flags.

`include "common_inc.vh"

module fp_classify #(
    parameter WIDTH  = 16
) (
    input  [WIDTH-1:0] in,

    output is_snan,          // Signaling Not a Number
    output is_qnan,          // Quiet Not a Number
    output is_neg_inf,       // Negative Infinity
    output is_neg_normal,    // Negative Normal Number
    output is_neg_denormal,  // Negative Denormalized Number
    output is_neg_zero,      // Negative Zero
    output is_pos_zero,      // Positive Zero
    output is_pos_denormal,  // Positive Denormalized Number
    output is_pos_normal,    // Positive Normal Number
    output is_pos_inf        // Positive Infinity
);
    `VERIF_DECLARE_PIPELINE(0)  // Verification Support

    // Derived parameters for convenience
    localparam EXP_W        = (WIDTH == 64) ?   11 : (WIDTH == 32) ?    8 : (WIDTH == 16) ?    5 : 0; // IEEE-754

    localparam MANT_W       = WIDTH - 1 - EXP_W;
    localparam SIGN_POS     = WIDTH - 1;
    localparam EXP_POS      = MANT_W;

    // Constants for special values
    localparam [ EXP_W-1:0] EXP_ALL_ONES   = { EXP_W{1'b1}};
    localparam [ EXP_W-1:0] EXP_ALL_ZEROS  = { EXP_W{1'b0}};
    localparam [MANT_W-1:0] MANT_ALL_ZEROS = {MANT_W{1'b0}};

    //----------------------------------------------------------------
    // Input Unpacking
    //----------------------------------------------------------------

    // Input value parts
    wire              sign = in[SIGN_POS];
    wire [ EXP_W-1:0] exp  = in[SIGN_POS-1:EXP_POS];
    wire [MANT_W-1:0] mant = in[MANT_W-1:0];

    // Intermediate category checks based on IEEE 754 standard
    wire exp_is_all_ones  = (exp  == EXP_ALL_ONES);
    wire exp_is_all_zeros = (exp  == EXP_ALL_ZEROS);
    wire mant_is_zero     = (mant == MANT_ALL_ZEROS);

    wire is_zero     = exp_is_all_zeros &&  mant_is_zero;
    wire is_inf      = exp_is_all_ones  &&  mant_is_zero;
    wire is_nan      = exp_is_all_ones  && !mant_is_zero;
    wire is_denormal = exp_is_all_zeros && !mant_is_zero;
    wire is_normal   = !exp_is_all_ones && !exp_is_all_zeros;

    // The MSB of the mantissa determines if a NaN is Signaling or Quiet
    // IEEE 754-2008: A quiet NaN bit should be the MSB of the mantissa.
    assign is_qnan = is_nan &&  mant[MANT_W-1];
    assign is_snan = is_nan && !mant[MANT_W-1];

    // Assign final outputs based on the sign bit
    assign is_neg_inf       = is_inf      &&  sign;
    assign is_neg_normal    = is_normal   &&  sign;
    assign is_neg_denormal  = is_denormal &&  sign;
    assign is_neg_zero      = is_zero     &&  sign;

    assign is_pos_zero      = is_zero     && !sign;
    assign is_pos_denormal  = is_denormal && !sign;
    assign is_pos_normal    = is_normal   && !sign;
    assign is_pos_inf       = is_inf      && !sign;

endmodule
