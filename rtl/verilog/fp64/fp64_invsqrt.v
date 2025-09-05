// fp64_invsqrt.v
//
// Verilog RTL for 64-bit float inverse square root (1/sqrt(x)).
//
// NOTE: This is a complex, combinational block. For synthesis, this
// should be converted to a multi-cycle pipeline.

module fp64_invsqrt (
    input  [63:0] fp_in,
    output reg [63:0] fp_out
);

    wire sign_in = fp_in[63];
    wire [10:0] exp_in = fp_in[62:52];
    wire [51:0] mant_in = fp_in[51:0];
    
    wire is_neg = sign_in && !((exp_in == 0) && (mant_in == 0));
    wire is_nan = (exp_in == 11'h7FF) && (mant_in != 0);
    wire is_inf = (exp_in == 11'h7FF) && (mant_in == 0);
    wire is_zero = (exp_in == 0) && (mant_in == 0);

    localparam P = 54;
    
    wire [P:0] y0;

    // N-R Iteration: y1 = y0 * (1.5 - (x/2) * y0^2)
    wire [2*P+1:0] y0_sq = y0 * y0;
    wire [52:0] mant_div2 = {(exp_in - 1 != 0), mant_in};
    wire [52+2*P+1:0] mul1_div2 = mant_div2 * y0_sq;
    wire signed [P+2:0] sub_res = (3'b011 << (P-1)) - mul1_div2[52+P:0];
    wire [2*P+2:0] y1 = y0 * sub_res;
    
    invsqrt_lut_64b lut (.addr({exp_in[0], mant_in[51:43]}), .data(y0));

    always @(*) begin
        if (is_nan || is_neg) begin
            fp_out = 64'h7FF8000000000001;
        end else if (is_inf) begin
            fp_out = 64'h0;
        end else if (is_zero) begin
            fp_out = 64'h7FF0000000000000;
        end else begin
            reg signed [11:0] exp_out_unnorm;
            reg [51:0] mant_out_final;
            
            exp_out_unnorm = (3*1023 - exp_in) >> 1;

            if (y1[2*P]) begin
                mant_out_final = y1[2*P-1 : 2*P-52];
            end else begin
                exp_out_unnorm = exp_out_unnorm - 1;
                mant_out_final = y1[2*P-2 : 2*P-53];
            end
            fp_out = {1'b0, exp_out_unnorm[10:0], mant_out_final};
        end
    end
endmodule
