// rtl/verilog/fp64/fp64_to_fp16.v
//
// Converts a 64-bit double-precision float to a 16-bit half-precision float.
//
// Features:
// - Uses fp_classify for special case handling.
// - Handles overflow (to infinity) and underflow (to denormalized/zero).
// - Truncates mantissa on conversion.
// - Uses simple, sequential assignments for better compiler compatibility.

module fp64_to_fp16 (
    input  [63:0] fp64_in,
    output reg [15:0] fp16_out
);

    //==================================================================
    // 1. Classification of the FP64 Input
    //==================================================================
    wire is_snan, is_qnan, is_neg_inf, is_pos_inf, is_neg_norm, is_pos_norm,
         is_neg_denorm, is_pos_denorm, is_neg_zero, is_pos_zero;

    fp_classify #(64) classifier (
        .in(fp64_in),
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
    // 2. Unpack FP64 components
    //==================================================================
    wire        sign_in = fp64_in[63];
    wire [10:0] exp_in  = fp64_in[62:52];
    wire [51:0] mant_in = fp64_in[51:0];

    //==================================================================
    // 3. Conversion Logic
    //==================================================================
    reg [15:0] temp_nan;
    reg signed [11:0] new_exp;
    reg [ 9:0] new_mant;
    reg [52:0] full_mant;
    reg [11:0] shift_amount;
    always @(*) begin
        if (is_nan) begin
            // Propagate NaN, converting to a 16-bit qNaN.
            temp_nan = {sign_in, 5'h1F, mant_in[51:42]};
            temp_nan[9] = 1'b1; // Ensure it's a quiet NaN
            fp16_out = temp_nan;
        end
        else if (is_inf) begin
            fp16_out = {sign_in, 5'h1F, 10'b0};
        end
        else if (is_zero) begin
            fp16_out = {sign_in, 15'b0};
        end
        else begin // Is normal or denormal (denormal fp64 is treated as zero fp16)

            // Adjust exponent for the new bias. (15 - 1023 = -1008)
            new_exp = exp_in - 1008;

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
                shift_amount = 1 - new_exp + 42;
                
                // Shift right to create the denormalized mantissa
                // The +42 is because we are truncating from 52 bits to 10 bits
                new_mant = full_mant >> shift_amount;

                fp16_out = {sign_in, 5'b0, new_mant};
            end
            else begin // Normal number
                // Truncate mantissa by taking the top 10 bits
                new_mant = mant_in[51:42];
                fp16_out = {sign_in, new_exp[4:0], new_mant};
            end
        end
    end

endmodule
