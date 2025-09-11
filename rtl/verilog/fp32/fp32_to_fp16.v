// fp32_to_fp16.v
//
// Verilog RTL to convert a 32-bit float to a 16-bit float.
//
// Features:
// - Combinational logic.
// - Handles NaN, Infinity, Zero.
// - Saturates on overflow (to Infinity).
// - Handles underflow (to denormalized or zero).
// - Truncates mantissa.

module fp32_to_fp16 (
    input  [31:0] fp32_in,
    output reg [15:0] fp16_out
);

    wire sign = fp32_in[31];
    wire [7:0] exp32 = fp32_in[30:23];
    wire [22:0] mant32 = fp32_in[22:0];

    wire is_nan32 = (exp32 == 8'hFF) && (mant32 != 0);
    wire is_inf32 = (exp32 == 8'hFF) && (mant32 == 0);
    wire is_zero32 = (exp32 == 0) && (mant32 == 0);
    
    // FP16 Exponent range:
    // Max normal: 15 (biased 30)
    // Min normal: -14 (biased 1)
    
    integer shift_amount;
    reg signed [ 8:0] true_exp;
    reg        [23:0] full_mant32;
    reg        [ 4:0] exp16;
    reg        [ 9:0] mant16;
    always @(*) begin
        if (is_nan32) begin
            fp16_out = {sign, 5'h1F, {1'b1, mant32[22:13]}}; // Propagate quiet NaN
        end else if (is_inf32) begin
            fp16_out = {sign, 5'h1F, 10'b0};
        end else if (is_zero32) begin
            fp16_out = {sign, 15'b0};
        end else begin
            true_exp = exp32 - 127;
            
            if (true_exp > 15) begin // Overflow
                fp16_out = {sign, 5'h1F, 10'b0}; // Infinity
            end else if (true_exp < -24) begin // Underflow to zero
                fp16_out = {sign, 15'b0};
            end else if (true_exp < -14) begin // Underflow to denormalized
                full_mant32 = {1'b1, mant32};
                shift_amount = -14 - true_exp;
                mant16 = (full_mant32 >> shift_amount) >> 13;
                fp16_out = {sign, 5'b0, mant16};
            end else begin // Normal conversion
                exp16 = true_exp + 15;
                mant16 = mant32[22:13];
                fp16_out = {sign, exp16, mant16};
            end
        end
    end
endmodule
