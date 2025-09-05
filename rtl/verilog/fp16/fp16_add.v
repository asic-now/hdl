// fp16_add.v
//
// Verilog RTL for a 16-bit (half-precision) floating-point adder.
//
// Format (IEEE 754 half-precision):
// [15]   : Sign bit (1 for negative, 0 for positive)
// [14:10]: 5-bit exponent (bias of 15)
// [9:0]  : 10-bit mantissa (fraction)
//
// Features:
// - 3-stage pipelined architecture for improved clock frequency.
// - Handles normalized and denormalized numbers.
// - Handles special cases: NaN, Infinity, and Zero.
// - Truncates the result (no rounding).

module fp16_add (
    input clk,
    input rst_n,

    input  [15:0] a,
    input  [15:0] b,

    output [15:0] result
);

    //----------------------------------------------------------------
    // Stage 1: Unpack, Compare, and Align
    //----------------------------------------------------------------
    // Unpack inputs a and b
    wire sign_a = a[15];
    wire [4:0] exp_a = a[14:10];
    wire [9:0] mant_a = a[9:0];

    wire sign_b = b[15];
    wire [4:0] exp_b = b[14:10];
    wire [9:0] mant_b = b[9:0];

    // Detect special values
    wire is_zero_a = (exp_a == 5'b0) && (mant_a == 10'b0);
    wire is_inf_a  = (exp_a == 5'h1F) && (mant_a == 10'b0);
    wire is_nan_a  = (exp_a == 5'h1F) && (mant_a != 10'b0);

    wire is_zero_b = (exp_b == 5'b0) && (mant_b == 10'b0);
    wire is_inf_b  = (exp_b == 5'h1F) && (mant_b == 10'b0);
    wire is_nan_b  = (exp_b == 5'h1F) && (mant_b != 10'b0);

    // Add the implicit leading bit for normalized numbers (1.fraction)
    // For denormalized numbers (exp=0), the implicit bit is 0 (0.fraction)
    wire [10:0] full_mant_a = {(exp_a != 0), mant_a};
    wire [10:0] full_mant_b = {(exp_b != 0), mant_b};

    // Stage 1 pipeline registers
    reg [4:0]  s1_larger_exp;
    reg        s1_result_sign;
    reg        s1_op_is_sub;
    reg [21:0] s1_mant_a; // Extended mantissa for alignment and guard bits
    reg [21:0] s1_mant_b;
    reg        s1_special_case;
    reg [15:0] s1_special_result;

    always @(*) begin
        // Combinational logic for Stage 1
        wire [4:0] exp_diff;
        wire [10:0] temp_mant_a, temp_mant_b;
        wire sign_larger, sign_smaller;
        reg [4:0] larger_exp_comb;

        // Magnitude comparison to determine alignment and result sign for subtraction
        if (exp_a > exp_b || (exp_a == exp_b && mant_a >= mant_b)) begin
            larger_exp_comb = exp_a;
            exp_diff = exp_a - exp_b;
            temp_mant_a = full_mant_a;
            temp_mant_b = full_mant_b;
            sign_larger = sign_a;
            sign_smaller = sign_b;
        end else begin
            larger_exp_comb = exp_b;
            exp_diff = exp_b - exp_a;
            temp_mant_a = full_mant_b;
            temp_mant_b = full_mant_a;
            sign_larger = sign_b;
            sign_smaller = sign_a;
        end

        // Align the mantissa of the smaller number by shifting it right
        s1_mant_a = {temp_mant_a, 11'b0};
        s1_mant_b = {temp_mant_b, 11'b0} >> exp_diff;
        
        // Set up for stage 2
        s1_larger_exp = larger_exp_comb;
        s1_result_sign = sign_larger;
        s1_op_is_sub = (sign_larger != sign_smaller);

        // Handle special cases - bypass the main logic
        s1_special_case = 1'b0;
        s1_special_result = 16'h7C01; // Default to a quiet NaN

        if (is_nan_a || is_nan_b) begin
            s1_special_case = 1'b1;
            s1_special_result = 16'h7C01; // Return quiet NaN
        end else if (is_inf_a && is_inf_b) begin
             s1_special_case = (sign_a != sign_b); // Result is NaN if signs differ
             s1_special_result = (sign_a == sign_b) ? a : 16'h7C01;
        end else if (is_inf_a) begin
            s1_special_case = 1'b1;
            s1_special_result = a;
        end else if (is_inf_b) begin
            s1_special_case = 1'b1;
            s1_special_result = b;
        end else if (is_zero_a) begin
            s1_special_case = 1'b1;
            s1_special_result = b;
        end else if (is_zero_b) {
            s1_special_case = 1'b1;
            s1_special_result = a;
        end
    end

    //----------------------------------------------------------------
    // Stage 2: Add or Subtract
    //----------------------------------------------------------------
    reg [4:0]  s2_exp;
    reg        s2_sign;
    reg [22:0] s2_mant; // Extra bit for carry/borrow
    reg        s2_special_case;
    reg [15:0] s2_special_result;

    always @(posedge clk) begin
        if (!rst_n) begin
            s2_exp <= 5'b0;
            s2_sign <= 1'b0;
            s2_mant <= 23'b0;
            s2_special_case <= 1'b0;
            s2_special_result <= 16'b0;
        end else begin
            if (s1_op_is_sub) begin
                s2_mant <= s1_mant_a - s1_mant_b;
            end else begin
                s2_mant <= s1_mant_a + s1_mant_b;
            end
            s2_exp <= s1_larger_exp;
            s2_sign <= s1_result_sign;
            s2_special_case <= s1_special_case;
            s2_special_result <= s1_special_result;
        end
    end

    //----------------------------------------------------------------
    // Stage 3: Normalize and Pack
    //----------------------------------------------------------------
    reg [15:0] result_reg;

    always @(posedge clk) begin
        if (!rst_n) begin
            result_reg <= 16'b0;
        end else begin
            if (s2_special_case) begin
                result_reg <= s2_special_result;
            end else begin
                // Normalize the result from the adder/subtractor
                reg [4:0] shift_amount;
                reg signed [5:0] final_exp;
                reg [22:0] final_mant;

                final_mant = s2_mant;
                final_exp = s2_exp;

                if (s2_mant == 0) begin
                    // Result is zero
                    final_exp = 0;
                end else if (s2_mant[22]) begin // Overflow from addition
                    final_exp = s2_exp + 1;
                    final_mant = s2_mant >> 1;
                end else begin // Check for leading zeros after subtraction
                    // Find first '1' to normalize (priority encoder)
                    // This is a simplified, synthesizable version of a priority encoder
                    // A more optimized version might use a case statement or function.
                    shift_amount = 0;
                    if (final_mant[21:11] == 0) begin // Check upper bits first
                         if      (!final_mant[21]) shift_amount = shift_amount + 1;
                         if      (!final_mant[20]) shift_amount = shift_amount + 1;
                         // ... and so on. This becomes very verbose.
                         // Let's use a more compact (but potentially slower) approach for clarity.
                         
                         // A more practical approach is to find the amount to shift left
                         integer i;
                         for (i = 21; i >= 0; i = i - 1) begin
                             if (final_mant[i]) begin
                                 shift_amount = 21 - i;
                             end
                         end

                         final_mant = final_mant << shift_amount;
                         final_exp = s2_exp - shift_amount;
                    end
                end

                // Pack the final result
                reg [9:0] out_mant;
                reg [4:0] out_exp;
                
                // Truncate mantissa to 10 bits, removing the implicit leading 1
                out_mant = final_mant[20:11];

                // Check for overflow/underflow on final exponent
                if (final_exp >= 31) begin // Overflow -> Infinity
                    out_exp = 5'h1F;
                    out_mant = 10'b0;
                end else if (final_exp <= 0) begin // Underflow -> Denormalized or Zero
                    // Shift mantissa right for denormalized representation
                    out_mant = (final_mant[21:11]) >> (1 - final_exp);
                    out_exp = 5'b0;
                end else begin
                    out_exp = final_exp[4:0];
                end

                if (out_exp == 0 && out_mant == 0) begin
                    // Ensure zero result has a positive sign
                    result_reg <= 16'b0;
                end else begin
                    result_reg <= {s2_sign, out_exp, out_mant};
                end
            end
        end
    end

    // Assign final registered output
    assign result = result_reg;

endmodule
