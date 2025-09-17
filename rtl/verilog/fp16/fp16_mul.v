// fp16_mul.v
//
// Verilog RTL for a 16-bit (half-precision) floating-point multiplier.
//
// Format (IEEE 754 half-precision):
// [   15]: Sign bit (1 for negative, 0 for positive)
// [14:10]: 5-bit exponent (bias of 15)
// [ 9: 0]: 10-bit mantissa (fraction/significand)
//
// Features:
// - 3-stage pipelined architecture.
// - Handles normalized and denormalized numbers.
// - Handles special cases: NaN, Infinity, and Zero.
// - Truncates the result (no rounding).

module fp16_mul (
    input clk,
    input rst_n,

    input  [15:0] a,
    input  [15:0] b,

    output [15:0] result
);

    //----------------------------------------------------------------
    // Stage 1: Unpack and Initial Calculations
    //----------------------------------------------------------------

    // Unpack inputs a and b
    wire       sign_a = a[15];
    wire [4:0] exp_a  = a[14:10];
    wire [9:0] mant_a = a[9:0];

    wire       sign_b = b[15];
    wire [4:0] exp_b  = b[14:10];
    wire [9:0] mant_b = b[9:0];

    // Detect special values
    wire is_zero_a = (exp_a == 5'b0) && (mant_a == 10'b0);
    wire is_inf_a  = (exp_a == 5'h1F) && (mant_a == 10'b0);
    wire is_nan_a  = (exp_a == 5'h1F) && (mant_a != 10'b0);

    wire is_zero_b = (exp_b == 5'b0) && (mant_b == 10'b0);
    wire is_inf_b  = (exp_b == 5'h1F) && (mant_b == 10'b0);
    wire is_nan_b  = (exp_b == 5'h1F) && (mant_b != 10'b0);

    // Add the implicit leading bit (1 for normalized, 0 for denormalized)
    wire [10:0] full_mant_a = {(exp_a != 0), mant_a};
    wire [10:0] full_mant_b = {(exp_b != 0), mant_b};

    // Handle denormalized inputs where the effective exponent is 1, not 0.
    wire [5:0] effective_exp_a = (exp_a == 0) ? 1 : exp_a;
    wire [5:0] effective_exp_b = (exp_b == 0) ? 1 : exp_b;

    // Stage 1 pipeline registers
    reg signed [5:0] s1_exp_sum;
    reg              s1_sign;
    reg [10:0]       s1_mant_a;
    reg [10:0]       s1_mant_b;
    reg              s1_special_case;
    reg [15:0]       s1_special_result;

    always @(*) begin
        // Combinational logic for Stage 1
        
        // Exponents are biased by 15. So, E_res = (E_a - 15) + (E_b - 15) = (E_a + E_b) - 30
        // New exponent = E_a + E_b - 15.
        // Need to handle denormalized numbers, where exponent is effectively 1-bias, not 0-bias.
        
        s1_exp_sum = effective_exp_a + effective_exp_b - 15;
        s1_sign = sign_a ^ sign_b;
        s1_mant_a = full_mant_a;
        s1_mant_b = full_mant_b;

        // Handle special cases - bypass the main logic
        s1_special_case = 1'b0;
        s1_special_result = 16'h7E01; // Default to a quiet NaN

        if (is_nan_a || is_nan_b) begin
            s1_special_case = 1'b1;
            s1_special_result = 16'h7C01; // NaN * anything = NaN
        end else if ((is_inf_a && is_zero_b) || (is_zero_a && is_inf_b)) begin
            s1_special_case = 1'b1;
            s1_special_result = 16'h7C01; // Inf * 0 = NaN
        end else if (is_inf_a || is_inf_b) begin
            s1_special_case = 1'b1;
            s1_special_result = {s1_sign, 5'h1F, 10'b0}; // Inf * anything = Inf
        end else if (is_zero_a || is_zero_b) begin
            s1_special_case = 1'b1;
            s1_special_result = {s1_sign, 15'b0}; // Zero * anything = Zero
        end
    end

    //----------------------------------------------------------------
    // Stage 2: Mantissa Multiplication
    //----------------------------------------------------------------
    reg signed [ 5:0] s2_exp;
    reg               s2_sign;
    reg        [21:0] s2_mant_product;
    reg               s2_special_case;
    reg        [15:0] s2_special_result;

    always @(posedge clk) begin
        if (!rst_n) begin
            s2_exp <= 6'b0;
            s2_sign <= 1'b0;
            s2_mant_product <= 22'b0;
            s2_special_case <= 1'b0;
            s2_special_result <= 16'b0;
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
    reg [15:0] result_reg;

    reg signed [ 5:0] final_exp;
    reg        [21:0] norm_mant;
    reg        [ 9:0] out_mant;
    reg        [ 4:0] out_exp;
    always @(posedge clk) begin
        if (!rst_n) begin
            result_reg <= 16'b0;
        end else begin
            if (s2_special_case) begin
                result_reg <= s2_special_result;
            end else begin
                // Normalize the result from the multiplier

                // The product of two 11-bit mantissas (1.f * 1.f) results in a 22-bit number.
                // The result is either 01.f or 1x.f.
                // If MSB (bit 21) is 1, it means the result is >= 2.0, so we shift right by 1
                // and increment the exponent.
                if (s2_mant_product[21]) begin // Normalized form is 1x.xxxx...
                    final_exp = s2_exp + 1;
                    norm_mant = s2_mant_product >> 1;
                end else begin // Normalized form is 01.xxxx...
                    final_exp = s2_exp;
                    norm_mant = s2_mant_product;
                end

                // Pack the final result
                
                // Truncate mantissa to 10 bits. The implicit bit is at index 20 of norm_mant.
                out_mant = norm_mant[19:10];

                // Check for overflow/underflow on final exponent
                if (final_exp >= 31) begin // Overflow -> Infinity
                    out_exp = 5'h1F;
                    out_mant = 10'b0;
                end else if (final_exp <= 0) begin // Underflow -> Denormalized or Zero
                    // Shift mantissa right for denormalized representation
                    // The implicit 1 is at norm_mant[20]
                    out_mant = ({1'b1, norm_mant[19:0]}) >> (1 - final_exp);
                    out_exp = 5'b0;
                end else begin
                    out_exp = final_exp[4:0];
                end

                if (out_exp == 0 && out_mant == 0) begin
                     // Result is exactly zero
                    result_reg <= {s2_sign, 15'b0};
                end else begin
                    result_reg <= {s2_sign, out_exp, out_mant};
                end
            end
        end
    end

    // Assign final registered output
    assign result = result_reg;

endmodule
