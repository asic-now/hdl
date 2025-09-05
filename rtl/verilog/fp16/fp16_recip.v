// fp16_recip.v
//
// Verilog RTL for a 16-bit (half-precision) floating-point reciprocal (1/x).
//
// Features:
// - Combinational logic (should be pipelined for synthesis).
// - Uses a Lookup Table (LUT) for an initial guess.
// - Refines the guess with one Newton-Raphson iteration.
// - Handles all special cases (NaN, Infinity, Zero).

module fp16_recip (
    input  [15:0] fp_in,
    output reg [15:0] fp_out
);

    // Unpack input
    wire sign_in = fp_in[15];
    wire [4:0] exp_in = fp_in[14:10];
    wire [9:0] mant_in = fp_in[9:0];
    wire [10:0] full_mant_in = {(exp_in != 0), mant_in};

    // Detect special values
    wire is_nan = (exp_in == 5'h1F) && (mant_in != 0);
    wire is_inf = (exp_in == 5'h1F) && (mant_in == 0);
    wire is_zero = (exp_in == 0) && (mant_in == 0);

    // Internal fixed-point precision for calculation
    localparam P = 12; // Use 12 bits of fractional precision

    // Wires for Newton-Raphson iteration: y1 = y0 * (2 - x * y0)
    wire [P:0] y0; // Initial guess (1.P format)
    wire [10+P+1:0] mul1_res; // x * y0
    wire signed [P+2:0] sub_res; // 2 - (x*y0)
    wire [P+P+2:0] mul2_res; // y0 * sub_res

    // LUT for initial guess of 1 / (1.mant)
    // Input: Top 4 bits of mantissa. Output: 1.P fixed-point.
    reciprocal_lut_16b lut (
        .addr(mant_in[9:6]),
        .data(y0)
    );

    // --- Newton-Raphson Calculation (Combinational) ---
    // For synthesis, this block should be heavily pipelined.
    
    // mul1 = full_mant_in * y0
    assign mul1_res = full_mant_in * y0;
    
    // sub = 2.0 - mul1_res
    assign sub_res = (2'b10 << P) - mul1_res[10+P:0];

    // mul2 = y0 * sub_res
    assign mul2_res = y0 * sub_res;
    // --- End of Combinational Calculation ---

    always @(*) begin
        if (is_nan) begin
            fp_out = 16'h7C01; // qNaN
        end else if (is_inf) begin
            fp_out = {sign_in, 15'b0}; // 1/inf -> 0
        end else if (is_zero) begin
            fp_out = {sign_in, 5'h1F, 10'b0}; // 1/0 -> inf
        end else begin
            // Normal calculation
            reg signed [5:0] exp_out_unnorm;
            reg [P+1:0] mant_out_unnorm;

            // The reciprocal of a normalized mantissa is in (0.5, 1.0].
            // If the result is < 1.0, we need to normalize.
            if (mul2_res[P+P+1]) begin // Result is 1.xxxx...
                exp_out_unnorm = 2 * 15 - exp_in - 1;
                mant_out_unnorm = mul2_res[P+P : P];
            end else begin // Result is 0.1xxx..., normalize
                exp_out_unnorm = 2 * 15 - exp_in - 2;
                mant_out_unnorm = mul2_res[P+P-1 : P-1];
            end
            
            // Pack the final result
            if (exp_out_unnorm >= 31) begin // Overflow -> inf
                fp_out = {sign_in, 5'h1F, 10'b0};
            end else if (exp_out_unnorm <= 0) begin // Underflow -> zero/denorm
                fp_out = {sign_in, 15'b0}; // Simplified to zero
            end else begin
                fp_out = {sign_in, exp_out_unnorm[4:0], mant_out_unnorm[P-1:P-10]};
            end
        end
    end

endmodule
