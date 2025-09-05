// fp64_to_fp32.v
//
// Verilog RTL to convert a 64-bit float to a 32-bit float.
//
// Features:
// - Combinational logic.
// - Handles NaN, Infinity, Zero.
// - Saturates on overflow (to Infinity).
// - Handles underflow (to denormalized or zero).
// - Truncates mantissa.

module fp64_to_fp32 (
    input  [63:0] fp64_in,
    output reg [31:0] fp32_out
);

    wire sign = fp64_in[63];
    wire [10:0] exp64 = fp64_in[62:52];
    wire [51:0] mant64 = fp64_in[51:0];

    wire is_nan64 = (exp64 == 11'h7FF) && (mant64 != 0);
    wire is_inf64 = (exp64 == 11'h7FF) && (mant64 == 0);
    wire is_zero64 = (exp64 == 0) && (mant64 == 0);

    // FP32 Exponent range:
    // Max normal: 127 (biased 254)
    // Min normal: -126 (biased 1)

    always @(*) begin
        if (is_nan64) begin
            fp32_out = {sign, 8'hFF, {1'b1, mant64[51:29]}}; // Propagate quiet NaN
        end else if (is_inf64) begin
            fp32_out = {sign, 8'hFF, 23'b0};
        end else if (is_zero64) begin
            fp32_out = {sign, 31'b0};
        end else begin
            reg signed [11:0] true_exp = exp64 - 1023;
            
            if (true_exp > 127) begin // Overflow
                fp32_out = {sign, 8'hFF, 23'b0}; // Infinity
            end else if (true_exp < -149) begin // Underflow to zero
                fp32_out = {sign, 31'b0};
            end else if (true_exp < -126) begin // Underflow to denormalized
                reg [22:0] mant32;
                reg [52:0] full_mant64 = {1'b1, mant64};
                integer shift_amount = -126 - true_exp;
                mant32 = (full_mant64 >> shift_amount) >> 29;
                fp32_out = {sign, 8'b0, mant32};
            end else begin // Normal conversion
                reg [7:0] exp32 = true_exp + 127;
                reg [22:0] mant32 = mant64[51:29];
                fp32_out = {sign, exp32, mant32};
            end
        end
    end
endmodule
