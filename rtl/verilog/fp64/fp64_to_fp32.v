// rtl/verilog/fp64/fp64_to_fp32.v
//
// Converts a 64-bit double-precision float to a 32-bit single-precision float.
//
// Features:
// - Uses fp_classify for special case handling.
// - Handles overflow (to infinity) and underflow (to denormalized/zero).
// - Truncates mantissa on conversion.
// - Uses simple, sequential assignments for better compiler compatibility.

module fp64_to_fp32 (
    input  [63:0] fp64_in,
    output reg [31:0] fp32_out
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
    reg [31:0] temp_nan;
    reg signed [11:0] new_exp;
    reg [22:0] new_mant;
    reg [52:0] full_mant;
    reg [11:0] shift_amount;
    always @(*) begin
        if (is_nan) begin
            // Propagate NaN, converting to a 32-bit qNaN.
            temp_nan = {sign_in, 8'hFF, mant_in[51:29]};
            temp_nan[22] = 1'b1; // Ensure it's a quiet NaN
            fp32_out = temp_nan;
        end
        else if (is_inf) begin
            fp32_out = {sign_in, 8'hFF, 23'b0};
        end
        else if (is_zero) begin
            fp32_out = {sign_in, 31'b0};
        end
        else begin // Is normal or denormal (denormal fp64 is treated as zero fp32)

            // Adjust exponent for the new bias. (127 - 1023 = -896)
            new_exp = exp_in - 896;

            if (new_exp > 254) begin // Overflow
                fp32_out = {sign_in, 8'hFF, 23'b0}; // Becomes infinity
            end
            else if (new_exp < -22) begin // Underflow completely to zero
                fp32_out = {sign_in, 31'b0};
            end
            else if (new_exp < 1) begin // Underflow to denormalized
                
                full_mant = {1'b1, mant_in};
                
                // Calculate how far to shift right
                shift_amount = 1 - new_exp + 29;
                
                // Perform the shift
                new_mant = full_mant >> shift_amount;

                fp32_out = {sign_in, 8'b0, new_mant};
            end
            else begin // Normal number
                // Truncate mantissa
                new_mant = mant_in[51:29];
                fp32_out = {sign_in, new_exp[7:0], new_mant};
            end
        end
    end

endmodule
