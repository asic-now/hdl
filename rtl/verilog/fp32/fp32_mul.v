// fp32_mul.v
//
// Verilog RTL for a 32-bit (single-precision) floating-point multiplier.
//
// Format (IEEE 754 single-precision):
// [31]   : Sign bit (1 for negative, 0 for positive)
// [30:23]: 8-bit exponent (bias of 127)
// [22:0] : 23-bit mantissa (fraction)
//
// Features:
// - 3-stage pipelined architecture.
// - Handles normalized and denormalized numbers.
// - Handles special cases: NaN, Infinity, and Zero.
// - Truncates the result (no rounding).

module fp32_mul (
    input clk,
    input rst_n,

    input  [31:0] a,
    input  [31:0] b,

    output [31:0] result
);

    //----------------------------------------------------------------
    // Stage 1: Unpack and Initial Calculations
    //----------------------------------------------------------------

    // Unpack inputs a and b
    wire        sign_a = a[31];
    wire [ 7:0] exp_a  = a[30:23];
    wire [22:0] mant_a = a[22:0];

    wire        sign_b = b[31];
    wire [ 7:0] exp_b  = b[30:23];
    wire [22:0] mant_b = b[22:0];

    // Detect special values
    wire is_zero_a = (exp_a == 8'b0) && (mant_a == 23'b0);
    wire is_inf_a  = (exp_a == 8'hFF) && (mant_a == 23'b0);
    wire is_nan_a  = (exp_a == 8'hFF) && (mant_a != 23'b0);

    wire is_zero_b = (exp_b == 8'b0) && (mant_b == 23'b0);
    wire is_inf_b  = (exp_b == 8'hFF) && (mant_b == 23'b0);
    wire is_nan_b  = (exp_b == 8'hFF) && (mant_b != 23'b0);

    // Add the implicit leading bit (1 for normalized, 0 for denormalized)
    wire [23:0] full_mant_a = {(exp_a != 0), mant_a};
    wire [23:0] full_mant_b = {(exp_b != 0), mant_b};

    // Handle denormalized inputs where the effective exponent is 1, not 0.
    wire [8:0] effective_exp_a = (exp_a == 0) ? 9'd1 : {1'b0, exp_a};
    wire [8:0] effective_exp_b = (exp_b == 0) ? 9'd1 : {1'b0, exp_b};

    // Stage 1 pipeline registers
    reg signed [ 8:0] s1_exp_sum;
    reg               s1_sign;
    reg        [23:0] s1_mant_a;
    reg        [23:0] s1_mant_b;
    reg               s1_special_case;
    reg        [31:0] s1_special_result;

    always @(*) begin
        // Combinational logic for Stage 1
        
        // Exponent calculation: new_exp = exp_a + exp_b - bias (127)
        
        s1_exp_sum = effective_exp_a + effective_exp_b - 127;
        s1_sign = sign_a ^ sign_b;
        s1_mant_a = full_mant_a;
        s1_mant_b = full_mant_b;

        // Handle special cases - bypass the main logic
        s1_special_case = 1'b0;
        s1_special_result = 32'h7FC00001; // Default to a quiet NaN

        if (is_nan_a || is_nan_b) begin
            s1_special_case = 1'b1;
            s1_special_result = 32'h7FC00001; // NaN * anything = NaN
        end else if ((is_inf_a && is_zero_b) || (is_zero_a && is_inf_b)) begin
            s1_special_case = 1'b1;
            s1_special_result = 32'h7FC00001; // Inf * 0 = NaN
        end else if (is_inf_a || is_inf_b) begin
            s1_special_case = 1'b1;
            s1_special_result = {s1_sign, 8'hFF, 23'b0}; // Inf * anything = Inf
        end else if (is_zero_a || is_zero_b) begin
            s1_special_case = 1'b1;
            s1_special_result = {s1_sign, 31'b0}; // Zero * anything = Zero
        end
    end

    //----------------------------------------------------------------
    // Stage 2: Mantissa Multiplication
    //----------------------------------------------------------------
    reg signed [ 8:0] s2_exp;
    reg               s2_sign;
    reg        [47:0] s2_mant_product;
    reg               s2_special_case;
    reg        [31:0] s2_special_result;

    always @(posedge clk) begin
        if (!rst_n) begin
            s2_exp <= 9'b0;
            s2_sign <= 1'b0;
            s2_mant_product <= 48'b0;
            s2_special_case <= 1'b0;
            s2_special_result <= 32'b0;
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
    reg [31:0] result_reg;

    reg signed [ 8:0] final_exp;
    reg        [47:0] norm_mant;
    reg        [22:0] out_mant;
    reg        [ 7:0] out_exp;
    always @(posedge clk) begin
        if (!rst_n) begin
            result_reg <= 32'b0;
        end else begin
            if (s2_special_case) begin
                result_reg <= s2_special_result;
            end else begin
                // Normalize the result from the multiplier

                // The product of two 24-bit mantissas (1.f * 1.f) is 48 bits.
                // The result is either 01.f... (bit 46 is 1) or 1x.f... (bit 47 is 1).
                // If bit 47 is 1, the result is >= 2.0. Normalize by shifting right by 1
                // and incrementing the exponent.
                if (s2_mant_product[47]) begin 
                    final_exp = s2_exp + 1;
                    norm_mant = s2_mant_product >> 1;
                end else begin
                    final_exp = s2_exp;
                    norm_mant = s2_mant_product;
                end

                // Pack the final result
                
                // Truncate mantissa to 23 bits. The implicit bit is at index 46 of norm_mant.
                out_mant = norm_mant[45:23];

                // Check for overflow/underflow on final exponent
                if (final_exp >= 255) begin // Overflow -> Infinity
                    out_exp = 8'hFF;
                    out_mant = 23'b0;
                end else if (final_exp <= 0) begin // Underflow -> Denormalized or Zero
                    // Shift mantissa right for denormalized representation
                    // The implicit 1 is at norm_mant[46]
                    out_mant = ({1'b1, norm_mant[45:0]}) >> (1 - final_exp);
                    out_exp = 8'b0;
                end else begin
                    out_exp = final_exp[7:0];
                end

                if (out_exp == 0 && out_mant == 0) begin
                     // Result is exactly zero
                    result_reg <= {s2_sign, 31'b0};
                end else begin
                    result_reg <= {s2_sign, out_exp, out_mant};
                end
            end
        end
    end

    // Assign final registered output
    assign result = result_reg;

endmodule
