// fp16_invsqrt.v
//
// Verilog RTL for 16-bit float inverse square root (1/sqrt(x)).
//
// Features:
// - Combinational logic (should be pipelined for synthesis).
// - LUT for initial guess.
// - One Newton-Raphson iteration: y1 = y0 * (1.5 - (x/2) * y0^2)
// - Handles all special cases.

module fp16_invsqrt (
    input  [15:0] fp_in,
    output reg [15:0] fp_out
);

    wire sign_in = fp_in[15];
    wire [4:0] exp_in = fp_in[14:10];
    wire [9:0] mant_in = fp_in[9:0];
    
    wire is_neg = sign_in && !((exp_in == 0) && (mant_in == 0));
    wire is_nan = (exp_in == 5'h1F) && (mant_in != 0);
    wire is_inf = (exp_in == 5'h1F) && (mant_in == 0);
    wire is_zero = (exp_in == 0) && (mant_in == 0);

    localparam P = 12; // Internal fractional precision

    // Wires for N-R iteration
    wire [P:0] y0;
    wire [2*P+1:0] y0_sq; // y0^2
    wire [10+2*P+2:0] mul1_res; // x * y0^2
    wire [10+2*P+1:0] mul1_div2; // (x/2) * y0^2
    wire signed [P+2:0] sub_res; // 1.5 - mul1_div2
    wire [2*P+2:0] y1; // y0 * sub_res

    // LUT gets top mantissa bits and exponent LSB
    invsqrt_lut_16b lut (
        .addr({exp_in[0], mant_in[9:6]}),
        .data(y0)
    );

    // --- Newton-Raphson Calculation (Combinational) ---
    assign y0_sq = y0 * y0;
    assign mul1_res = {1'b0, (exp_in != 0), mant_in} * y0_sq;

    // x/2 is a simple exponent adjustment on the FP input
    wire [4:0] exp_div2 = exp_in - 1;
    wire [10:0] mant_div2 = {(exp_div2 != 0), mant_in};
    
    assign mul1_div2 = mant_div2 * y0_sq;

    // 1.5 is 3/2 -> 1.1 in binary
    assign sub_res = (3'b011 << (P-1)) - mul1_div2[10+P:0];
    
    assign y1 = y0 * sub_res;
    // --- End of Combinational Calculation ---
    
    always @(*) begin
        if (is_nan || is_neg) begin
            fp_out = 16'h7C01; // qNaN
        end else if (is_inf) begin
            fp_out = 16'h0000; // 1/sqrt(inf) -> 0
        end else if (is_zero) begin
            fp_out = 16'h7C00; // 1/sqrt(0) -> inf
        end else begin
            reg signed [5:0] exp_out_unnorm;
            reg [9:0] mant_out_final;
            
            // Exponent is approx (3*bias - E)/2
            exp_out_unnorm = (3*15 - exp_in) >> 1;

            // Normalize the mantissa result 'y1'
            // Result is always in [0.5, 1.0) range before final mul, so we look at top two bits
            if (y1[2*P]) begin // 1.xxxx
                mant_out_final = y1[2*P-1 : 2*P-10];
            end else begin // 0.1xxx
                exp_out_unnorm = exp_out_unnorm - 1;
                mant_out_final = y1[2*P-2 : 2*P-11];
            end

            fp_out = {1'b0, exp_out_unnorm[4:0], mant_out_final};
        end
    end

endmodule

// Placeholder for invsqrt LUT
module invsqrt_lut_16b (input [4:0] addr, output [12:0] data);
    // This LUT would contain pre-calculated values for 1/sqrt(M)
    // where M depends on both mantissa and if exponent was odd/even
    assign data = 13'h1000; // Simplified placeholder
endmodule
