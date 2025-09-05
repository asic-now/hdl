// fp64_recip.v
//
// Verilog RTL for a 64-bit (double-precision) floating-point reciprocal (1/x).
//
// NOTE: This is a complex, combinational block. For synthesis, this
// should be converted to a multi-cycle pipeline.

module fp64_recip (
    input  [63:0] fp_in,
    output reg [63:0] fp_out
);
    wire sign_in = fp_in[63];
    wire [10:0] exp_in = fp_in[62:52];
    wire [51:0] mant_in = fp_in[51:0];

    wire is_nan = (exp_in == 11'h7FF) && (mant_in != 0);
    wire is_inf = (exp_in == 11'h7FF) && (mant_in == 0);
    wire is_zero = (exp_in == 0) && (mant_in == 0);

    localparam P = 54;

    wire [P:0] y0;
    reciprocal_lut_64b lut (.addr(mant_in[51:42]), .data(y0)); // 10-bit LUT

    // N-R Iteration: y1 = y0 * (2 - x * y0)
    wire [52:0] x_norm = {(exp_in != 0), mant_in};
    wire [52+P+1:0] mul1_res = x_norm * y0;
    wire signed [P+2:0] sub_res = (2'b10 << P) - mul1_res[52+P:0];
    wire [P+P+2:0] mul2_res = y0 * sub_res;

    always @(*) begin
        if (is_nan) begin
            fp_out = 64'h7FF8000000000001;
        end else if (is_inf) begin
            fp_out = {sign_in, 63'b0};
        end else if (is_zero) begin
            fp_out = {sign_in, 11'h7FF, 52'b0};
        end else begin
            reg signed [11:0] exp_out_unnorm;
            reg [P+1:0] mant_out_unnorm;

            if (mul2_res[P+P+1]) begin
                exp_out_unnorm = 2 * 1023 - exp_in - 1;
                mant_out_unnorm = mul2_res[P+P : P];
            end else begin
                exp_out_unnorm = 2 * 1023 - exp_in - 2;
                mant_out_unnorm = mul2_res[P+P-1 : P-1];
            end
            
            if (exp_out_unnorm >= 2047) begin
                fp_out = {sign_in, 11'h7FF, 52'b0};
            end else if (exp_out_unnorm <= 0) begin
                fp_out = {sign_in, 63'b0};
            end else begin
                fp_out = {sign_in, exp_out_unnorm[10:0], mant_out_unnorm[P-1:P-52]};
            end
        end
    end
endmodule
