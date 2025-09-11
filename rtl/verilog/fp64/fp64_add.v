// fp64_add.v
//
// Verilog RTL for a 64-bit (double-precision) floating-point adder.
//
// Format (IEEE 754 double-precision):
// [63]   : Sign bit
// [62:52]: 11-bit exponent (bias of 1023)
// [51:0] : 52-bit mantissa (fraction)
//
// Features:
// - 3-stage pipelined architecture for improved clock frequency.
// - Handles normalized and denormalized numbers.
// - Handles special cases: NaN, Infinity, and Zero.
// - Truncates the result (no rounding implemented).

module fp64_add (
    input clk,
    input rst_n,

    input  [63:0] a,
    input  [63:0] b,

    output [63:0] result
);

    //----------------------------------------------------------------
    // Stage 1: Unpack, Compare, and Align
    //----------------------------------------------------------------
    
    // Unpack inputs a and b
    wire        sign_a = a[63];
    wire [10:0] exp_a  = a[62:52];
    wire [51:0] mant_a = a[51:0];

    wire        sign_b = b[63];
    wire [10:0] exp_b  = b[62:52];
    wire [51:0] mant_b = b[51:0];

    // Detect special values
    wire is_zero_a = (exp_a == 11'b0) && (mant_a == 52'b0);
    wire is_inf_a  = (exp_a == 11'h7FF) && (mant_a == 52'b0);
    wire is_nan_a  = (exp_a == 11'h7FF) && (mant_a != 52'b0);

    wire is_zero_b = (exp_b == 11'b0) && (mant_b == 52'b0);
    wire is_inf_b  = (exp_b == 11'h7FF) && (mant_b == 52'b0);
    wire is_nan_b  = (exp_b == 11'h7FF) && (mant_b != 52'b0);

    // Add the implicit leading bit for normalized numbers (1.fraction)
    wire [52:0] full_mant_a = {(exp_a != 0), mant_a};
    wire [52:0] full_mant_b = {(exp_b != 0), mant_b};

    // Stage 1 pipeline registers
    reg  [ 10:0] s1_larger_exp;
    reg          s1_result_sign;
    reg          s1_op_is_sub;
    reg  [105:0] s1_mant_a; // Extended mantissa for alignment (53 + 53)
    reg  [105:0] s1_mant_b;
    reg          s1_special_case;
    reg  [ 63:0] s1_special_result;

    reg  [ 10:0] exp_diff;
    reg  [ 52:0] temp_mant_a, temp_mant_b;
    reg          sign_larger, sign_smaller;
    reg  [ 10:0] larger_exp_comb;
    always @(*) begin
        // Combinational logic for Stage 1

        // Magnitude comparison to determine alignment and result sign
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
        s1_mant_a = {temp_mant_a, 53'b0};
        s1_mant_b = {temp_mant_b, 53'b0} >> exp_diff;
        
        // Set up for stage 2
        s1_larger_exp = larger_exp_comb;
        s1_result_sign = sign_larger;
        s1_op_is_sub = (sign_larger != sign_smaller);

        // Handle special cases - bypass the main logic
        s1_special_case = 1'b0;
        s1_special_result = 64'h7FF8000000000001; // Default to a quiet NaN

        if (is_nan_a || is_nan_b) begin
            s1_special_case = 1'b1;
            s1_special_result = 64'h7FF8000000000001; // Return quiet NaN
        end else if (is_inf_a && is_inf_b) begin
             s1_special_case = (sign_a != sign_b); // Result is NaN if signs differ (inf - inf)
             s1_special_result = (sign_a == sign_b) ? a : 64'h7FF8000000000001;
        end else if (is_inf_a) begin
            s1_special_case = 1'b1;
            s1_special_result = a;
        end else if (is_inf_b) begin
            s1_special_case = 1'b1;
            s1_special_result = b;
        end else if (is_zero_a) begin
            s1_special_case = 1'b1;
            s1_special_result = b;
        end else if (is_zero_b) begin
            s1_special_case = 1'b1;
            s1_special_result = a;
        end
    end

    //----------------------------------------------------------------
    // Stage 2: Add or Subtract
    //----------------------------------------------------------------
    reg  [ 10:0] s2_exp;
    reg          s2_sign;
    reg  [106:0] s2_mant; // Extra bit for carry/borrow
    reg          s2_special_case;
    reg  [ 63:0] s2_special_result;

    always @(posedge clk) begin
        if (!rst_n) begin
            s2_exp <= 11'b0;
            s2_sign <= 1'b0;
            s2_mant <= 107'b0;
            s2_special_case <= 1'b0;
            s2_special_result <= 64'b0;
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
    integer shift_amount;
    reg         [ 63:0] result_reg;
    reg         [ 51:0] out_mant;
    reg         [ 10:0] out_exp;
    reg  signed [ 11:0] final_exp;
    reg         [106:0] final_mant;
    always @(posedge clk) begin
        if (!rst_n) begin
            result_reg <= 64'b0;
        end else begin
            if (s2_special_case) begin
                result_reg <= s2_special_result;
            end else begin
                // Normalize the result from the adder/subtractor

                final_mant = s2_mant;
                final_exp = s2_exp;

                if (s2_mant == 0) begin
                    // Result is zero
                    final_exp = 0;
                end else if (s2_mant[106]) begin // Overflow from addition
                    final_exp = s2_exp + 1;
                    final_mant = s2_mant >> 1;
                end else if (s2_mant[105] == 0) begin // Normalize after subtraction
                    // Find first '1' to normalize (leading zero counter)
                    shift_amount = 0;
                    // This synthesizes to a priority encoder
                    for (integer i = 105; i >= 0; i = i - 1) begin
                        if (final_mant[i]) begin
                            shift_amount = 105 - i;
                        end
                    end
                    final_mant = final_mant << shift_amount;
                    final_exp = s2_exp - shift_amount;
                end

                // Pack the final result
                
                // Truncate mantissa to 52 bits, removing the implicit leading 1
                out_mant = final_mant[104:53];

                // Check for overflow/underflow on final exponent
                if (final_exp >= 2047) begin // Overflow -> Infinity
                    out_exp = 11'h7FF;
                    out_mant = 52'b0;
                end else if (final_exp <= 0) begin // Underflow -> Denormalized or Zero
                    out_mant = ({1'b1, final_mant[104:0]}) >> (1 - final_exp);
                    out_exp = 11'b0;
                end else begin
                    out_exp = final_exp[10:0];
                end

                if (out_exp == 0 && out_mant == 0) begin
                    // Ensure zero result has a positive sign
                    result_reg <= 64'b0;
                end else begin
                    result_reg <= {s2_sign, out_exp, out_mant};
                end
            end
        end
    end

    // Assign final registered output
    assign result = result_reg;

endmodule
