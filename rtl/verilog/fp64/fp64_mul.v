// fp64_mul.v
//
// Verilog RTL for a 64-bit (double-precision) floating-point multiplier.
//
// Format (IEEE 754 double-precision):
// [63]   : Sign bit
// [62:52]: 11-bit exponent (bias of 1023)
// [51:0] : 52-bit mantissa (fraction)
//
// Features:
// - 3-stage pipelined architecture.
// - Handles normalized and denormalized numbers.
// - Handles special cases: NaN, Infinity, and Zero.
// - Truncates the result (no rounding).

module fp64_mul (
    input clk,
    input rst_n,

    input  [63:0] a,
    input  [63:0] b,

    output [63:0] result
);

    //----------------------------------------------------------------
    // Stage 1: Unpack and Initial Calculations
    //----------------------------------------------------------------

    // Unpack inputs a and b
    wire sign_a = a[63];
    wire [10:0] exp_a = a[62:52];
    wire [51:0] mant_a = a[51:0];

    wire sign_b = b[63];
    wire [10:0] exp_b = b[62:52];
    wire [51:0] mant_b = b[51:0];

    // Detect special values
    wire is_zero_a = (exp_a == 11'b0) && (mant_a == 52'b0);
    wire is_inf_a  = (exp_a == 11'h7FF) && (mant_a == 52'b0);
    wire is_nan_a  = (exp_a == 11'h7FF) && (mant_a != 52'b0);

    wire is_zero_b = (exp_b == 11'b0) && (mant_b == 52'b0);
    wire is_inf_b  = (exp_b == 11'h7FF) && (mant_b == 52'b0);
    wire is_nan_b  = (exp_b == 11'h7FF) && (mant_b != 52'b0);

    // Add the implicit leading bit
    wire [52:0] full_mant_a = {(exp_a != 0), mant_a};
    wire [52:0] full_mant_b = {(exp_b != 0), mant_b};

    // Stage 1 pipeline registers
    reg signed [11:0] s1_exp_sum;
    reg              s1_sign;
    reg [52:0]       s1_mant_a;
    reg [52:0]       s1_mant_b;
    reg              s1_special_case;
    reg [63:0]       s1_special_result;

    always @(*) begin
        // Combinational logic for Stage 1
        
        // Exponent calculation: new_exp = exp_a + exp_b - bias (1023)
        // Handle denormalized inputs where the effective exponent is 1.
        wire [11:0] effective_exp_a = (exp_a == 0) ? 12'd1 : {1'b0, exp_a};
        wire [11:0] effective_exp_b = (exp_b == 0) ? 12'd1 : {1'b0, exp_b};
        
        s1_exp_sum = effective_exp_a + effective_exp_b - 1023;
        s1_sign = sign_a ^ sign_b;
        s1_mant_a = full_mant_a;
        s1_mant_b = full_mant_b;

        // Handle special cases - bypass the main logic
        s1_special_case = 1'b0;
        s1_special_result = 64'h7FF8000000000001; // Default to a quiet NaN

        if (is_nan_a || is_nan_b) begin
            s1_special_case = 1'b1;
            s1_special_result = 64'h7FF8000000000001; // NaN * anything = NaN
        end else if ((is_inf_a && is_zero_b) || (is_zero_a && is_inf_b)) begin
            s1_special_case = 1'b1;
            s1_special_result = 64'h7FF8000000000001; // Inf * 0 = NaN
        end else if (is_inf_a || is_inf_b) begin
            s1_special_case = 1'b1;
            s1_special_result = {s1_sign, 11'h7FF, 52'b0}; // Inf * anything = Inf
        end else if (is_zero_a || is_zero_b) {
            s1_special_case = 1'b1;
            s1_special_result = {s1_sign, 63'b0}; // Zero * anything = Zero
        end
    end

    //----------------------------------------------------------------
    // Stage 2: Mantissa Multiplication
    //----------------------------------------------------------------
    reg signed [11:0] s2_exp;
    reg              s2_sign;
    reg [105:0]      s2_mant_product;
    reg              s2_special_case;
    reg [63:0]       s2_special_result;

    always @(posedge clk) begin
        if (!rst_n) begin
            s2_exp <= 12'b0;
            s2_sign <= 1'b0;
            s2_mant_product <= 106'b0;
            s2_special_case <= 1'b0;
            s2_special_result <= 64'b0;
        end else begin
            s2_mant_product <= s1_mant_a * s1_mant_b;
            s2_exp <= s1_exp_sum;
            s2_sign <= s1_sign;
            s2_special_case <= s1_special_case;
            s2_special_result <= s1_special_result;
        end
    end

    //----------------------------------------------------------------
    // Stage 3: Normalize and Pack
    //----------------------------------------------------------------
    reg [63:0] result_reg;

    always @(posedge clk) begin
        if (!rst_n) begin
            result_reg <= 64'b0;
        end else begin
            if (s2_special_case) begin
                result_reg <= s2_special_result;
            end else begin
                // Normalize the result from the multiplier
                reg signed [11:0] final_exp;
                reg [105:0]       norm_mant;

                // The product of two 53-bit mantissas is 106 bits.
                // The result is either 01.f... (bit 104 is 1) or 1x.f... (bit 105 is 1).
                // If bit 105 is 1, the result is >= 2.0. Normalize by shifting right by 1
                // and incrementing the exponent.
                if (s2_mant_product[105]) begin 
                    final_exp = s2_exp + 1;
                    norm_mant = s2_mant_product >> 1;
                end else begin
                    final_exp = s2_exp;
                    norm_mant = s2_mant_product;
                end

                // Pack the final result
                reg [51:0] out_mant;
                reg [10:0] out_exp;
                
                // Truncate mantissa to 52 bits. The implicit bit is at index 104 of norm_mant.
                out_mant = norm_mant[103:52];

                // Check for overflow/underflow on final exponent
                if (final_exp >= 2047) begin // Overflow -> Infinity
                    out_exp = 11'h7FF;
                    out_mant = 52'b0;
                end else if (final_exp <= 0) begin // Underflow -> Denormalized or Zero
                    out_mant = ({1'b1, norm_mant[103:0]}) >> (1 - final_exp);
                    out_exp = 11'b0;
                end else begin
                    out_exp = final_exp[10:0];
                end

                if (out_exp == 0 && out_mant == 0) begin
                     // Result is exactly zero
                    result_reg <= {s2_sign, 63'b0};
                end else begin
                    result_reg <= {s2_sign, out_exp, out_mant};
                end
            end
        end
    end

    // Assign final registered output
    assign result = result_reg;

endmodule
