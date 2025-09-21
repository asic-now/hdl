// rtl/verilog/fp32/fp32_to_fp16.v
//
// Converts a 32-bit single-precision float to a 16-bit half-precision float.
//
// Features:
// - Refactored to use fp32_classify for special case handling.
// - Handles overflow (to infinity) and underflow (to denormalized/zero).
// - Truncates mantissa on conversion.
// - Uses simple, sequential assignments for better compiler compatibility.

module fp32_to_fp16 (
    input  [31:0] fp32_in,
    output reg [15:0] fp16_out
);

    //==================================================================
    // 1. Classification of the FP32 Input
    //==================================================================
    wire is_snan, is_qnan, is_neg_inf, is_pos_inf, is_neg_norm, is_pos_norm,
         is_neg_denorm, is_pos_denorm, is_neg_zero, is_pos_zero;

    fp32_classify classifier (
        .in(fp32_in),
        .is_snan(is_snan), .is_qnan(is_qnan),
        .is_neg_inf(is_neg_inf), .is_pos_inf(is_pos_inf),
        .is_neg_norm(is_neg_norm), .is_pos_norm(is_pos_norm),
        .is_neg_denorm(is_neg_denorm), .is_pos_denorm(is_pos_denorm),
        .is_neg_zero(is_neg_zero), .is_pos_zero(is_pos_zero)
    );

    wire is_nan = is_snan || is_qnan;
    wire is_inf = is_pos_inf || is_neg_inf;
    wire is_zero = is_pos_zero || is_neg_zero;

    //==================================================================
    // 2. Unpack FP32 components
    //==================================================================
    wire        sign_in = fp32_in[31];
    wire [ 7:0] exp_in  = fp32_in[30:23];
    wire [22:0] mant_in = fp32_in[22:0];

    //==================================================================
    // 3. Conversion Logic
    //==================================================================
    reg [15:0] temp_nan;
    reg signed [8:0] new_exp;
    reg [9:0] new_mant;
    reg [23:0] full_mant;
    reg [11:0] shift_amount;
    always @(*) begin
        if (is_nan) begin
            // Propagate NaN, converting to a 16-bit qNaN.
            temp_nan = {sign_in, 5'h1F, mant_in[22:13]};
            temp_nan[9] = 1'b1; // Ensure it's a quiet NaN
            fp16_out = temp_nan;
        end
        else if (is_inf) begin
            fp16_out = {sign_in, 5'h1F, 10'b0};
        end
        else if (is_zero) begin
            fp16_out = {sign_in, 15'b0};
        end
        else begin // Is normal or denormal (denormal fp32 is treated as zero fp16)

            // Adjust exponent for the new bias. (15 - 127 = -112)
            new_exp = exp_in - 112;

            if (new_exp > 30) begin // Overflow
                fp16_out = {sign_in, 5'h1F, 10'b0}; // Becomes infinity
            end
            else if (new_exp < -9) begin // Underflow completely to zero
                 fp16_out = {sign_in, 15'b0};
            end
            else if (new_exp < 1) begin // Underflow to denormalized
                // Create the full mantissa with the implicit '1'
                full_mant = {1'b1, mant_in};

                // Calculate how far to shift right
                shift_amount = 1 - new_exp + 13;

                // Shift right to create the denormalized mantissa
                new_mant = full_mant >> shift_amount;

                fp16_out = {sign_in, 5'b0, new_mant};
            end
            else begin // Normal number
                // Truncate mantissa
                new_mant = mant_in[22:13];
                fp16_out = {sign_in, new_exp[4:0], new_mant};
            end
        end
    end

endmodule
