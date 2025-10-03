// rtl/verilog/fp16/fp16_add.v
//
// Verilog RTL for a parameterized floating-point adder.
//
// This module is a 3-stage pipelined adder for IEEE 754 floating-point numbers.
// It can be configured for different precisions (e.g., fp16, fp32, fp64) by
// setting the WIDTH parameter.
//
// Features:
// - Parameterized for various precisions.
// - 3-stage pipelined architecture for improved clock frequency.
// - Handles normalized and denormalized numbers.
// - Handles special cases: NaN, Infinity, and Zero.
// - Truncates the result (no rounding implemented).

`include "common_inc.vh"

module fp16_add #(
    parameter WIDTH = 16 // Only 16,32,64 supported
) (
    input clk,
    input rst_n,

    input  [WIDTH-1:0] a,
    input  [WIDTH-1:0] b,

    output [WIDTH-1:0] result
);
    `VERIF_DECLARE_PIPELINE(3)  // Verification support

    // Derived parameters for convenience
    localparam EXP_W          = (WIDTH == 64) ?   11 : (WIDTH == 32) ?   8 : (WIDTH == 16) ?  5 : 0; // IEEE-754
    localparam EXP_BIAS       = (WIDTH == 64) ? 1023 : (WIDTH == 32) ? 127 : (WIDTH == 16) ? 15 : 0; // IEEE-754
    localparam PRECISION_BITS = (WIDTH == 64) ?   52 : (WIDTH == 32) ?  23 : (WIDTH == 16) ? 14 : 0; // Select mantissa precision for accurate rounding // TODO: (when needed) Correct values for WIDTH 64 and 32

    localparam MANT_W       = WIDTH - 1 - EXP_W;
    localparam SIGN_POS     = WIDTH - 1;
    localparam EXP_POS      = MANT_W;
    localparam ALIGN_MANT_W = MANT_W + 1 + PRECISION_BITS; // For alignment shift

    // Constants for special values
    localparam [ EXP_W-1:0] EXP_ALL_ONES   = { EXP_W{1'b1}};
    localparam [ EXP_W-1:0] EXP_ALL_ZEROS  = { EXP_W{1'b0}};
    localparam [MANT_W-1:0] MANT_ALL_ZEROS = {MANT_W{1'b0}};

    localparam [WIDTH-1:0] QNAN = {1'b0, EXP_ALL_ONES, {1'b1, {(MANT_W-1){1'b0}}}};
    localparam [WIDTH-1:0] P_ZERO = {1'b0, {(WIDTH-1){1'b0}}};
    localparam [WIDTH-1:0] N_ZERO = {1'b1, {(WIDTH-1){1'b0}}};


    //----------------------------------------------------------------
    // Input Unpacking
    //----------------------------------------------------------------

    // Input value parts
    wire              sign_a = a[SIGN_POS];
    wire [ EXP_W-1:0] exp_a  = a[SIGN_POS-1:EXP_POS];
    wire [MANT_W-1:0] mant_a = a[MANT_W-1:0];

    wire              sign_b = b[SIGN_POS];
    wire [ EXP_W-1:0] exp_b  = b[SIGN_POS-1:EXP_POS];
    wire [MANT_W-1:0] mant_b = b[MANT_W-1:0];

    // Detect special values
    // wire is_denorm_a = (exp_a == EXP_ALL_ZEROS) && (mant_a != MANT_ALL_ZEROS);
    // wire is_denorm_b = (exp_b == EXP_ALL_ZEROS) && (mant_b != MANT_ALL_ZEROS);
    wire is_zero_a   = (exp_a == EXP_ALL_ZEROS) && (mant_a == MANT_ALL_ZEROS);
    wire is_zero_b   = (exp_b == EXP_ALL_ZEROS) && (mant_b == MANT_ALL_ZEROS);
    wire is_inf_a    = (exp_a == EXP_ALL_ONES ) && (mant_a == MANT_ALL_ZEROS);
    wire is_inf_b    = (exp_b == EXP_ALL_ONES ) && (mant_b == MANT_ALL_ZEROS);
    wire is_nan_a    = (exp_a == EXP_ALL_ONES ) && (mant_a != MANT_ALL_ZEROS);
    wire is_nan_b    = (exp_b == EXP_ALL_ONES ) && (mant_b != MANT_ALL_ZEROS);

    // Add implicit leading bit (1 for normal, 0 for denormal/zero)
    wire [1+MANT_W-1:0] full_mant_a = {(exp_a != EXP_ALL_ZEROS), mant_a};
    wire [1+MANT_W-1:0] full_mant_b = {(exp_b != EXP_ALL_ZEROS), mant_b};

    //----------------------------------------------------------------
    // Stage 1: Unpack, Compare, and Align
    //----------------------------------------------------------------

    // Stage 1 Combinational Logic
    reg  signed [EXP_W:0]       exp_diff_d;  // +1 bit carry
    reg                         larger_sign_d;
    reg         [1+MANT_W-1:0]  larger_mant_in_d, smaller_mant_in_d;
    reg         [EXP_W-1:0]     larger_exp_in_d;
    always @(*) begin
        // Magnitude comparison to determine alignment and result sign
        if (exp_a > exp_b || (exp_a == exp_b && mant_a >= mant_b)) begin
            larger_exp_in_d   = exp_a;
            exp_diff_d        = {1'b0, exp_a} - {1'b0, exp_b};
            larger_mant_in_d  = full_mant_a;
            smaller_mant_in_d = full_mant_b;
            larger_sign_d     = sign_a;
        end else begin
            larger_exp_in_d   = exp_b;
            exp_diff_d        = {1'b0, exp_b} - {1'b0, exp_a};
            larger_mant_in_d  = full_mant_b;
            smaller_mant_in_d = full_mant_a;
            larger_sign_d     = sign_b;
        end
    end

    // Stage 1 Pipeline
    reg         [EXP_W-1:0]     s1_larger_exp_q;
    reg                         s1_result_sign_q;
    reg                         s1_op_is_sub_q;
    reg                         s1_neg_zero_q;
    reg         [ALIGN_MANT_W-1:0] s1_mant_a_q;  // Extended mantissa for alignment
    reg         [ALIGN_MANT_W-1:0] s1_mant_b_q;
    reg                         s1_special_case_q;
    reg         [WIDTH-1:0]     s1_special_result_q;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s1_larger_exp_q     <= 1'b0;
            s1_result_sign_q    <= 1'b0;
            s1_op_is_sub_q      <= 1'b0;
            s1_neg_zero_q       <= 1'b0;
            s1_mant_a_q         <= 0;
            s1_mant_b_q         <= 0;
            s1_special_case_q   <= 1'b0;
            s1_special_result_q <= P_ZERO;
        end else begin
            // Align the mantissa of the smaller number by shifting it right
            s1_mant_a_q <= ({larger_mant_in_d , {PRECISION_BITS{1'b0}}});
            s1_mant_b_q <= ({smaller_mant_in_d, {PRECISION_BITS{1'b0}}}) >> exp_diff_d;

            // Set up for stage 2
            s1_larger_exp_q  <= larger_exp_in_d;
            s1_result_sign_q <= larger_sign_d;
            s1_op_is_sub_q   <= (sign_a != sign_b);
            s1_neg_zero_q    <= (is_zero_a && is_zero_b && sign_a && sign_b);

            // Handle special cases - bypass the main logic
            s1_special_case_q <= 1'b0;
            s1_special_result_q <= QNAN; // Default to a quiet NaN

            if (is_nan_a || is_nan_b || (is_inf_a && is_inf_b && (sign_a != sign_b))) begin
                s1_special_case_q <= 1'b1;
                s1_special_result_q <= QNAN; // Return quiet NaN for any NaN or Inf-Inf
            end else if (is_inf_a) begin
                s1_special_case_q <= 1'b1;
                s1_special_result_q <= a;
            end else if (is_inf_b) begin
                s1_special_case_q <= 1'b1;
                s1_special_result_q <= b;
            end else if (is_zero_a) begin
                s1_special_case_q <= 1'b1;
                s1_special_result_q <= b;
            end else if (is_zero_b) begin
                s1_special_case_q <= 1'b1;
                s1_special_result_q <= a;
            end
        end
    end

    //----------------------------------------------------------------
    // Stage 2: Add or Subtract
    //----------------------------------------------------------------
    reg  [EXP_W-1:0]          s2_exp_q;
    reg                       s2_sign_q;
    reg  [1+ALIGN_MANT_W-1:0] s2_mant_q;  // 1 bit for carry
    reg                       s2_neg_zero_q;
    reg                       s2_special_case_q;
    reg  [WIDTH-1:0]          s2_special_result_q;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s2_exp_q            <= EXP_ALL_ZEROS;
            s2_sign_q           <= 1'b0;
            s2_mant_q           <= '0;
            s2_neg_zero_q       <= 1'b0;
            s2_special_case_q   <= 1'b0;
            s2_special_result_q <= P_ZERO;
        end else begin
            s2_exp_q            <= s1_larger_exp_q;
            s2_neg_zero_q       <= s1_neg_zero_q;
            s2_special_case_q   <= s1_special_case_q;
            s2_special_result_q <= s1_special_result_q;

            if (s1_op_is_sub_q) begin
                if (s1_mant_a_q >= s1_mant_b_q) begin
                    s2_mant_q <= {1'b0, s1_mant_a_q} - {1'b0, s1_mant_b_q};
                    s2_sign_q <= s1_result_sign_q;
                end else begin
                    s2_mant_q <= {1'b0, s1_mant_b_q} - {1'b0, s1_mant_a_q};
                    s2_sign_q <= ~s1_result_sign_q;
                end
            end else begin
                s2_mant_q <= {1'b0, s1_mant_a_q} + {1'b0, s1_mant_b_q};
                s2_sign_q <= s1_result_sign_q;
            end
        end
    end

    //----------------------------------------------------------------
    // Stage 3: Normalize and Pack
    //----------------------------------------------------------------

    // Stage 3 Combinational Logic
    reg         [ALIGN_MANT_W-1:0]   final_mant;
    reg  signed [EXP_W:0]            final_exp;
    integer                          msb_pos;
    integer                          i;
    reg  signed [EXP_W:0]            shift_val;
    reg         [MANT_W-1:0]         out_mant;
    reg         [EXP_W-1:0]          out_exp;
    always @(*) begin
        // Default normalization results
        final_exp = { 1'b0, s2_exp_q};
        final_mant = s2_mant_q[ALIGN_MANT_W-1:0]; // Start with mantissa, without the carry bit

        // Find MSB for normalization shift
        msb_pos = 0;
        // Parallel priority encoder - this loop is synthesizable.
        for (i = ALIGN_MANT_W; i >= 0; i = i - 1) begin
            if (s2_mant_q[i]) begin
                msb_pos = i;
                i = -1; // Verilog equivalent to break
            end
        end

        // The implicit '1' for a normalized number should be at bit ALIGN_MANT_W-1.
        // The denormalized implicit '0' is also at this position (for denorm to norm)
        shift_val = (ALIGN_MANT_W-1) - msb_pos;

        if (s2_mant_q == 0) begin
            // Result is zero, no normalization needed
            out_exp = EXP_ALL_ZEROS;
            out_mant = MANT_ALL_ZEROS;
        end else begin
            // Apply the shift and update the exponent
            if (shift_val > 0) begin
                final_mant = s2_mant_q << shift_val;
            end else begin
                final_mant = s2_mant_q >> (-shift_val);
            end
            final_exp = {1'b0, s2_exp_q} - shift_val;

            // Extract final mantissa, dropping the implicit bit at ALIGN_MANT_W-1
            out_mant = final_mant[ALIGN_MANT_W-2:ALIGN_MANT_W-2+1-MANT_W];

            // Check for overflow/underflow on final exponent
            if (final_exp >= EXP_ALL_ONES) begin // Overflow -> Infinity
                out_exp = EXP_ALL_ONES;
                out_mant = MANT_ALL_ZEROS;
            end else if (final_exp <= 0) begin // Underflow -> Denormalized or Zero
                // Note: This implementation flushes to zero on underflow,
                // a simplified approach to avoid complex denormalization.
                out_exp = EXP_ALL_ZEROS;
                out_mant = MANT_ALL_ZEROS;
            end else begin
                out_exp = final_exp[EXP_W-1:0];
            end
        end

    end

    // Stage 3 Pipeline
    reg         [WIDTH-1:0]          result_q;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result_q <= P_ZERO;
        end else begin
            if (s2_special_case_q) begin
                result_q <= s2_special_result_q;
            end else begin
                // Handle the sign of zero
                if (out_exp == EXP_ALL_ZEROS && out_mant == MANT_ALL_ZEROS) begin
                    // Per IEEE 754-2008, +0 + -0 = +0 and -0 + -0 = -0
                    result_q <= s2_neg_zero_q ? N_ZERO : P_ZERO;
                end else begin
                    result_q <= {s2_sign_q, out_exp, out_mant};
                end
            end
        end
    end

    // Assign final registered output
    assign result = result_q;

endmodule
