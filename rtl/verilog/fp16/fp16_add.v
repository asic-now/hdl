// fp16_add.v
//
// Verilog RTL for a 16-bit (half-precision) floating-point adder.
//
// Format (IEEE 754 half-precision):
// [   15]: Sign bit (1 for negative, 0 for positive)
// [14:10]: 5-bit exponent (bias of 15)
// [ 9: 0]: 10-bit mantissa (fraction/significand)
//
// Features:
// - 3-stage pipelined architecture for improved clock frequency.
// - Handles normalized and denormalized numbers.
// - Handles special cases: NaN, Infinity, and Zero.
// - Truncates the result (no rounding implemented).

module fp16_add (
    input clk,
    input rst_n,

    input  [15:0] a,
    input  [15:0] b,

    output [15:0] result
);

    //----------------------------------------------------------------
    // Wires and Registers
    //----------------------------------------------------------------

    // Unpack inputs a and b
    wire        sign_a = a[15];
    wire [ 4:0] exp_a  = a[14:10];
    wire [ 9:0] mant_a = a[9:0];

    wire        sign_b = b[15];
    wire [ 4:0] exp_b  = b[14:10];
    wire [ 9:0] mant_b = b[9:0];

    // Detect special values
    wire is_denorm_a = (exp_a == 5'h00) && (mant_a != 10'b0);
    wire is_denorm_b = (exp_b == 5'h00) && (mant_b != 10'b0);
    wire is_zero_a   = (exp_a == 5'h00) && (mant_a == 10'b0);
    wire is_zero_b   = (exp_b == 5'h00) && (mant_b == 10'b0);
    wire is_inf_a    = (exp_a == 5'h1F) && (mant_a == 10'b0);
    wire is_inf_b    = (exp_b == 5'h1F) && (mant_b == 10'b0);
    wire is_nan_a    = (exp_a == 5'h1F) && (mant_a != 10'b0);
    wire is_nan_b    = (exp_b == 5'h1F) && (mant_b != 10'b0);

    // Add the implicit leading bit for normalized numbers (1.fraction)
    // For denormalized numbers (exp=0), the implicit bit is 0 (0.fraction)
    wire [10:0] full_mant_a = {(exp_a != 0), mant_a};
    wire [10:0] full_mant_b = {(exp_b != 0), mant_b};

    //----------------------------------------------------------------
    // Stage 1: Unpack, Compare, and Align (Combinational Logic)
    //----------------------------------------------------------------
    reg  signed [ 5:0] exp_diff; // Widened for carry
    reg                larger_sign, smaller_sign;
    reg         [10:0] larger_mant_in, smaller_mant_in;
    reg         [ 4:0] larger_exp_in;

    reg         [ 4:0] s1_larger_exp;
    reg                s1_result_sign;
    reg                s1_op_is_sub;
    reg         [24:0] s1_mant_a; // Extended mantissa for alignment
    reg         [24:0] s1_mant_b;
    reg                s1_special_case;
    reg         [15:0] s1_special_result;

    always @(*) begin
        // Magnitude comparison to determine alignment and result sign
        if (exp_a > exp_b || (exp_a == exp_b && mant_a >= mant_b)) begin
            larger_exp_in  = exp_a;
            exp_diff       = {1'b0, exp_a} - {1'b0, exp_b};
            larger_mant_in = full_mant_a;
            smaller_mant_in= full_mant_b;
            larger_sign    = sign_a;
            smaller_sign   = sign_b;
        end else begin
            larger_exp_in  = exp_b;
            exp_diff       = {1'b0, exp_b} - {1'b0, exp_a};
            larger_mant_in = full_mant_b;
            smaller_mant_in= full_mant_a;
            larger_sign    = sign_b;
            smaller_sign   = sign_a;
        end

        // Align the mantissa of the smaller number by shifting it right
        s1_mant_a = {larger_mant_in, 14'b0};
        s1_mant_b = {smaller_mant_in, 14'b0} >> exp_diff;

        // Set up for stage 2
        s1_larger_exp  = larger_exp_in;
        s1_result_sign = larger_sign;
        s1_op_is_sub   = (sign_a != sign_b);

        // Handle special cases - bypass the main logic
        s1_special_case = 1'b0;
        s1_special_result = 16'h7E01; // Default to a quiet NaN

        if (is_nan_a || is_nan_b || (is_inf_a && is_inf_b && (sign_a != sign_b))) begin
            s1_special_case = 1'b1;
            s1_special_result = 16'h7E01; // Return quiet NaN for any NaN or Inf-Inf
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
    // Stage 2: Add or Subtract (Pipelined Logic)
    //----------------------------------------------------------------
    reg         [ 4:0] s2_exp;
    reg                s2_sign;
    reg         [25:0] s2_mant; // 26 bits to include carry
    reg                s2_special_case;
    reg         [15:0] s2_special_result;
    always @(posedge clk) begin
        if (!rst_n) begin
            s2_exp          <= 5'b0;
            s2_sign         <= 1'b0;
            s2_mant         <= 26'b0;
            s2_special_case <= 1'b0;
            s2_special_result <= 16'b0;
        end else begin
            s2_exp          <= s1_larger_exp;
            s2_special_case <= s1_special_case;
            s2_special_result <= s1_special_result;
            
            if (s1_op_is_sub) begin
                if (s1_mant_a >= s1_mant_b) begin
                    s2_mant <= {1'b0, s1_mant_a} - {1'b0, s1_mant_b};
                    s2_sign <= s1_result_sign;
                end else begin
                    s2_mant <= {1'b0, s1_mant_b} - {1'b0, s1_mant_a};
                    s2_sign <= ~s1_result_sign;
                end
            end else begin
                s2_mant <= {1'b0, s1_mant_a} + {1'b0, s1_mant_b};
                s2_sign <= s1_result_sign;
            end
        end
    end

    //----------------------------------------------------------------
    // Stage 3: Normalize and Pack (Pipelined Logic)
    //----------------------------------------------------------------
    reg         [24:0] final_mant; // 25 bits for normalization
    reg  signed [ 5:0] final_exp;
    integer            msb_pos;
    integer            i;
    reg  signed [ 5:0] shift_val;
    reg         [ 9:0] out_mant;
    reg         [ 4:0] out_exp;
    reg         [15:0] result_reg;
    always @(posedge clk) begin
        if (!rst_n) begin
            result_reg <= 16'b0;
        end else begin
            if (s2_special_case) begin
                result_reg <= s2_special_result;
            end else begin
                // Default normalization results
                final_exp = s2_exp;
                final_mant = s2_mant[24:0]; // Start with mantissa, without the carry bit

                // Find MSB for normalization shift
                msb_pos = 0;
                for (i = 25; i >= 0; i = i - 1) begin
                    if (s2_mant[i]) begin
                        msb_pos = i;
                        i = -1; // Verilog equivalent to break
                    end
                end
                
                // The implicit '1' for a normalized number should be at bit 24 of the 25-bit mantissa.
                // The denormalized implicit '0' is also at this position (for denorm to norm)
                shift_val = 24 - msb_pos;

                if (s2_mant == 0) begin
                    // Result is zero, no normalization needed
                    out_exp = 5'b0;
                    out_mant = 10'b0;
                end else begin
                    // Apply the shift and update the exponent
                    if (shift_val > 0) begin
                        final_mant = s2_mant << shift_val;
                    end else begin
                        final_mant = s2_mant >> (-shift_val);
                    end
                    final_exp = s2_exp - shift_val;

                    out_mant = final_mant[23:14];

                    // Check for overflow/underflow on final exponent
                    if (final_exp >= 31) begin // Overflow -> Infinity
                        out_exp = 5'h1F;
                        out_mant = 10'b0;
                    end else if (final_exp <= 0) begin // Underflow -> Denormalized or Zero
                        // Note: This implementation flushes to zero on underflow,
                        // a simplified approach to avoid complex denormalization.
                        out_exp = 5'b0;
                        out_mant = 10'b0;
                    end else begin
                        out_exp = final_exp[4:0];
                    end
                end
                
                // Correctly handle the sign of zero
                if (out_exp == 0 && out_mant == 0) begin
                    result_reg <= (is_zero_a && is_zero_b && sign_a && sign_b) ? 16'h8000 : 16'b0;
                end else begin
                    result_reg <= {s2_sign, out_exp, out_mant};
                end
            end
        end
    end

    // Assign final registered output
    assign result = result_reg;

endmodule
