// fp16_classify.v
//
// Verilog RTL for a 16-bit (half-precision) floating-point classifier.
// This module identifies the category of a given FP16 number.
//
// Outputs are mutually exclusive flags.

module fp16_classify (
    input  [15:0] in,

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
    wire sign      = in[15];
    wire [4:0] exp = in[14:10];
    wire [9:0] mant = in[9:0];

    // Intermediate category checks based on IEEE 754 standard
    wire exp_is_all_ones  = (exp == 5'h1F);
    wire exp_is_all_zeros = (exp == 5'h00);
    wire mant_is_zero     = (mant == 10'h000);

    wire is_nan      = exp_is_all_ones && !mant_is_zero;
    wire is_inf      = exp_is_all_ones && mant_is_zero;
    wire is_zero     = exp_is_all_zeros && mant_is_zero;
    wire is_denormal = exp_is_all_zeros && !mant_is_zero;
    wire is_normal   = !exp_is_all_ones && !exp_is_all_zeros;

    // The MSB of the mantissa determines if a NaN is Signaling or Quiet
    // IEEE 754-2008: A quiet NaN bit should be the MSB of the mantissa.
    assign is_qnan = is_nan && mant[9];
    assign is_snan = is_nan && !mant[9];

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
