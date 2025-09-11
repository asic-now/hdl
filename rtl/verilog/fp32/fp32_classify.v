// fp32_classify.v
//
// Verilog RTL for a 32-bit (single-precision) floating-point classifier.
// This module identifies the category of a given FP32 number.
//
// Outputs are mutually exclusive flags.

module fp32_classify (
    input  [31:0] in,

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

    // Unpack the input floating-point number
    wire        sign = in[31];
    wire [ 7:0] exp  = in[30:23];
    wire [22:0] mant = in[22:0];

    // Intermediate category checks based on IEEE 754 standard
    wire exp_is_all_ones  = (exp == 8'hFF);
    wire exp_is_all_zeros = (exp == 8'h00);
    wire mant_is_zero     = (mant == 23'h000000);

    wire is_nan      = exp_is_all_ones && !mant_is_zero;
    wire is_inf      = exp_is_all_ones && mant_is_zero;
    wire is_zero     = exp_is_all_zeros && mant_is_zero;
    wire is_denormal = exp_is_all_zeros && !mant_is_zero;
    wire is_normal   = !exp_is_all_ones && !exp_is_all_zeros;

    // The MSB of the mantissa determines if a NaN is Signaling or Quiet
    // IEEE 754-2008: A quiet NaN bit should be the MSB of the mantissa.
    assign is_qnan = is_nan && mant[22];
    assign is_snan = is_nan && !mant[22];

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
