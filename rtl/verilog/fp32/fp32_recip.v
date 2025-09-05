// fp32_recip.v
//
// Verilog RTL for a 32-bit (single-precision) floating-point reciprocal (1/x).
//
// NOTE: This is a complex, combinational block. For synthesis, this
// should be converted to a multi-cycle pipeline.

module fp32_recip (
    input  [31:0] fp_in,
    output reg [31:0] fp_out
);
    wire sign_in = fp_in[31];
    wire [7:0] exp_in = fp_in[30:23];
    wire [22:0] mant_in = fp_in[22:0];

    wire is_nan = (exp_in == 8'hFF) && (mant_in != 0);
    wire is_inf = (exp_in == 8'hFF) && (mant_in == 0);
    wire is_zero = (exp_in == 0) && (mant_in == 0);

    localparam P = 25; // Internal fractional precision

    wire [P:0] y0; // Initial guess
    
    // LUT with 8-bit address for better initial guess
    reciprocal_lut_32b lut (.addr(mant_in[22:15]), .data(y0));

    // N-R Iteration: y1 = y0 * (2 - x * y0)
    wire [23:0] x_norm = {(exp_in != 0), mant_in};
    wire [23+P+1:0] mul1_res = x_norm * y0;
    wire signed [P+2:0] sub_res = (2'b10 << P) - mul1_res[23+P:0];
    wire [P+P+2:0] mul2_res = y0 * sub_res;

    always @(*) begin
        if (is_nan) begin
            fp_out = 32'h7FC00001; // qNaN
        end else if (is_inf) begin
            fp_out = {sign_in, 31'b0};
        end else if (is_zero) begin
            fp_out = {sign_in, 8'hFF, 23'b0};
        end else begin
            reg signed [8:0] exp_out_unnorm;
            reg [P+1:0] mant_out_unnorm;

            if (mul2_res[P+P+1]) begin
                exp_out_unnorm = 2 * 127 - exp_in - 1;
                mant_out_unnorm = mul2_res[P+P : P];
            end else begin
                exp_out_unnorm = 2 * 127 - exp_in - 2;
                mant_out_unnorm = mul2_res[P+P-1 : P-1];
            end
            
            if (exp_out_unnorm >= 255) begin // Overflow
                fp_out = {sign_in, 8'hFF, 23'b0};
            end else if (exp_out_unnorm <= 0) begin // Underflow
                fp_out = {sign_in, 31'b0};
            end else begin
                fp_out = {sign_in, exp_out_unnorm[7:0], mant_out_unnorm[P-1:P-23]};
            end
        end
    end
endmodule
