// fp32_invsqrt.v
//
// Verilog RTL for 32-bit float inverse square root (1/sqrt(x)).
//
// NOTE: This is a complex, combinational block. For synthesis, this
// should be converted to a multi-cycle pipeline.

module fp32_invsqrt (
    input  [31:0] fp_in,
    output reg [31:0] fp_out
);

    wire        sign_in = fp_in[31];
    wire [ 7:0] exp_in  = fp_in[30:23];
    wire [22:0] mant_in = fp_in[22:0];
    
    wire is_neg = sign_in && !((exp_in == 0) && (mant_in == 0));
    wire is_nan = (exp_in == 8'hFF) && (mant_in != 0);
    wire is_inf = (exp_in == 8'hFF) && (mant_in == 0);
    wire is_zero = (exp_in == 0) && (mant_in == 0);

    localparam P = 25; // Internal fractional precision
    
    // Wires for N-R iteration
    wire [P:0] y0;

    // N-R Iteration: y1 = y0 * (1.5 - (x/2) * y0^2)
    wire [2*P+1:0] y0_sq = y0 * y0;
    wire [23:0] mant_div2 = {(exp_in - 1 != 0), mant_in};
    wire [23+2*P+1:0] mul1_div2 = mant_div2 * y0_sq;
    wire signed [P+2:0] sub_res = (3'b011 << (P-1)) - mul1_div2[23+P:0];
    wire [2*P+2:0] y1 = y0 * sub_res;
    
    // LUT on exponent LSB and top 7 mantissa bits
    invsqrt_lut_32b lut (
        .addr({exp_in[0], mant_in[22:16]}),
        .data(y0)
    );

    reg  signed [ 8:0] exp_out_unnorm;
    reg         [22:0] mant_out_final;
    always @(*) begin
        if (is_nan || is_neg) begin
            fp_out = 32'h7FC00001; // qNaN
        end else if (is_inf) begin
            fp_out = 32'h00000000;
        end else if (is_zero) begin
            fp_out = 32'h7F800000;
        end else begin
            
            exp_out_unnorm = (3*127 - exp_in) >> 1;

            if (y1[2*P]) begin
                mant_out_final = y1[2*P-1 : 2*P-23];
            end else begin
                exp_out_unnorm = exp_out_unnorm - 1;
                mant_out_final = y1[2*P-2 : 2*P-24];
            end
            fp_out = {1'b0, exp_out_unnorm[7:0], mant_out_final};
        end
    end
endmodule
