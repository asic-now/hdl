// rtl/verilog/fp/fp_mul.v
//
// Verilog RTL for a parameterized floating-point multiplier.
//
// This module is a pipelined multiplier for IEEE 754 floating-point numbers.
// It can be configured for different precisions (e.g., fp16, fp32, fp64) by
// setting the WIDTH parameter.
//
// Features:
// - Parameterized for various precisions.
// - pipelined architecture for improved clock frequency.
// - Handles normalized and denormalized numbers.
// - Handles special cases: NaN, Infinity, and Zero.
// - TODO: (when needed) Implements GRS rounding for improved accuracy.

`include "common_inc.vh"
`include "grs_round.vh" // Defines Rounding Modes

module fp_mul #(
    parameter WIDTH  = 16
) (
    input clk,
    input rst_n,

    input  [WIDTH-1:0] a,
    input  [WIDTH-1:0] b,
    // input  [2:0]       round_mode, // See grs_rounder.v for modes // TODO: (when needed) Implement dynamic port (caller can tie it to a constant if desired)

    output [WIDTH-1:0] result
);
    `VERIF_DECLARE_PIPELINE(4)  // Verification support

    // Derived parameters for convenience
    localparam EXP_W            = (WIDTH == 64) ?   11 : (WIDTH == 32) ?    8 : (WIDTH == 16) ?    5 : 0; // IEEE-754
    localparam EXP_BIAS         = (WIDTH == 64) ? 1023 : (WIDTH == 32) ?  127 : (WIDTH == 16) ?   15 : 0; // IEEE-754
    localparam PRECISION_BITS   = (WIDTH == 64) ?    5 : (WIDTH == 32) ?    5 : (WIDTH == 16) ?   14 : 0; // Select mantissa precision for accurate rounding
    localparam [2:0] round_mode = (WIDTH == 64) ? `RNE : (WIDTH == 32) ? `RNE : (WIDTH == 16) ? `RTZ : `RNE;

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
    wire is_zero_a   = (exp_a == EXP_ALL_ZEROS) && (mant_a == MANT_ALL_ZEROS);
    wire is_zero_b   = (exp_b == EXP_ALL_ZEROS) && (mant_b == MANT_ALL_ZEROS);
    wire is_inf_a    = (exp_a == EXP_ALL_ONES ) && (mant_a == MANT_ALL_ZEROS);
    wire is_inf_b    = (exp_b == EXP_ALL_ONES ) && (mant_b == MANT_ALL_ZEROS);
    wire is_nan_a    = (exp_a == EXP_ALL_ONES ) && (mant_a != MANT_ALL_ZEROS);
    wire is_nan_b    = (exp_b == EXP_ALL_ONES ) && (mant_b != MANT_ALL_ZEROS);

    // Add implicit leading bit (1 for normal, 0 for denormal/zero)
    wire [1+MANT_W-1:0] full_mant_a = {(exp_a != EXP_ALL_ZEROS), mant_a};
    wire [1+MANT_W-1:0] full_mant_b = {(exp_b != EXP_ALL_ZEROS), mant_b};

    // Handle denormalized inputs where the effective exponent is 1, not 0.
    wire [EXP_W-1:0] effective_exp_a = (exp_a == EXP_ALL_ZEROS) ? 1 : exp_a;
    wire [EXP_W-1:0] effective_exp_b = (exp_b == EXP_ALL_ZEROS) ? 1 : exp_b;

    //----------------------------------------------------------------
    // Stage 1: Unpack and Special Case Detection
    //----------------------------------------------------------------

    // Stage 1 - Combinational Logic
    reg signed [EXP_W+1:0] s1_exp_sum_d;
    reg                    s1_sign_d;
    reg        [MANT_W:0]  s1_mant_a_d;
    reg        [MANT_W:0]  s1_mant_b_d;
    reg                    s1_special_case_d;
    reg        [WIDTH-1:0] s1_special_result_d;
    always @(*) begin
        // Exponents are biased by EXP_BIAS. So, E_res = (E_a - EXP_BIAS) + (E_b - EXP_BIAS) = (E_a + E_b) - 2*EXP_BIAS
        // New biased exponent = E_res + EXP_BIAS = E_a + E_b - EXP_BIAS.
        // Need to handle denormalized numbers, where exponent is effectively 1-bias, not 0-bias.
        s1_exp_sum_d = $signed({2'b0,effective_exp_a}) + $signed({2'b0,effective_exp_b}) - $signed({2'b0,EXP_BIAS});
        s1_sign_d = sign_a ^ sign_b;
        s1_mant_a_d = full_mant_a;
        s1_mant_b_d = full_mant_b;

        // Handle special cases - bypass the main logic
        s1_special_case_d = 1'b0;
        s1_special_result_d = QNAN; // Default to a quiet NaN

        if (is_nan_a || is_nan_b) begin
            s1_special_case_d = 1'b1;
            s1_special_result_d = is_nan_a ? a : b; // NaN * anything = NaN (propagate one of them)
        end else if ((is_inf_a && is_zero_b) || (is_zero_a && is_inf_b)) begin
            s1_special_case_d = 1'b1;
            s1_special_result_d = QNAN; // Inf * 0 = NaN
        end else if (is_inf_a || is_inf_b) begin
            s1_special_case_d = 1'b1;
            s1_special_result_d = {s1_sign_d, EXP_ALL_ONES, MANT_ALL_ZEROS}; // Inf * anything = Inf
        end else if (is_zero_a || is_zero_b) begin
            s1_special_case_d = 1'b1;
            s1_special_result_d = s1_sign_d ? N_ZERO : P_ZERO; // Zero * anything = Zero
        end
    end

    // Stage 1 - Pipeline Registers
    reg signed [EXP_W+1:0] s1_exp_sum_q;
    reg                    s1_sign_q;
    reg [MANT_W:0]         s1_mant_a_q;
    reg [MANT_W:0]         s1_mant_b_q;
    reg                    s1_special_case_q;
    reg [WIDTH-1:0]        s1_special_result_q;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s1_exp_sum_q        <= '0;
            s1_sign_q           <= 1'b0;
            s1_mant_a_q         <= '0;
            s1_mant_b_q         <= '0;
            s1_special_case_q   <= 1'b0;
            s1_special_result_q <= P_ZERO;
        end else begin
            s1_exp_sum_q        <= s1_exp_sum_d;
            s1_sign_q           <= s1_sign_d;
            s1_mant_a_q         <= s1_mant_a_d;
            s1_mant_b_q         <= s1_mant_b_d;
            s1_special_case_q   <= s1_special_case_d;
            s1_special_result_q <= s1_special_result_d;
        end
    end

    //----------------------------------------------------------------
    // Stage 2: Mantissa Multiplication
    //----------------------------------------------------------------

    // Stage 2 - Combinational Logic
    wire [2*MANT_W+1:0] s2_mant_product_d = s1_mant_a_q * s1_mant_b_q;

    // Stage 2 - Pipeline Registers
    reg signed [EXP_W+1:0]    s2_exp_q;
    reg                       s2_sign_q;
    reg        [2*MANT_W+1:0] s2_mant_product_q;
    reg                       s2_special_case_q;
    reg        [WIDTH-1:0]    s2_special_result_q;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s2_exp_q            <= '0;
            s2_sign_q           <= 1'b0;
            s2_mant_product_q   <= '0;
            s2_special_case_q   <= 1'b0;
            s2_special_result_q <= P_ZERO;
        end else begin
            s2_exp_q            <= s1_exp_sum_q;
            s2_sign_q           <= s1_sign_q;
            s2_mant_product_q   <= s2_mant_product_d;
            s2_special_case_q   <= s1_special_case_q;
            s2_special_result_q <= s1_special_result_q;
        end
    end

    //----------------------------------------------------------------
    // Stage 3: Normalize and Pack
    //----------------------------------------------------------------

    // Stage 3 - Combinational Logic
    reg signed [EXP_W+1:0]   s3_exp_d;
    reg        [2*MANT_W:0]  s3_mant_d;
    always @(*) begin
        // The product of two (MANT_W+1)-bit mantissas (1.f * 1.f) results in a (2*MANT_W+2)-bit number.
        // The result is either 01.f or 1x.f.
        // If MSB (bit 2*MANT_W+1) is 1, it means the result is >= 2.0, so we shift right by 1
        // and increment the exponent.
        if (s2_mant_product_q[2*MANT_W+1]) begin // Normalized form is 1x.xxxx...
            s3_exp_d  = s2_exp_q + 1;
            s3_mant_d = s2_mant_product_q >> 1;
        end else begin // Normalized form is 01.xxxx...
            s3_exp_d  = s2_exp_q;
            s3_mant_d = s2_mant_product_q;
        end
    end

    // Stage 3 - Pipeline Registers
    reg signed [EXP_W+1:0]   s3_exp_q;
    reg                      s3_sign_q;
    reg        [2*MANT_W:0]  s3_mant_q;
    reg                      s3_special_case_q;
    reg        [WIDTH-1:0]   s3_special_result_q;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s3_exp_q            <= '0;
            s3_sign_q           <= 1'b0;
            s3_mant_q           <= '0;
            s3_special_case_q   <= 1'b0;
            s3_special_result_q <= P_ZERO;
        end else begin
            s3_exp_q            <= s3_exp_d;
            s3_sign_q           <= s2_sign_q;
            s3_mant_q           <= s3_mant_d;
            s3_special_case_q   <= s2_special_case_q;
            s3_special_result_q <= s2_special_result_q;
        end
    end

    //----------------------------------------------------------------
    // Final Stage (combinational): Round and Pack
    //----------------------------------------------------------------

    // 1. Determine the mantissa to be rounded.
    //    If the number is underflowing, it must be right-shifted before rounding.
    //    Otherwise, we round the normalized mantissa directly.
    wire is_underflow = (s3_exp_q <=  $signed({(EXP_W+2){1'b0}}));
    wire [2*MANT_W:0] mant_to_round;
    assign mant_to_round = is_underflow ? (s3_mant_q >> (1 - s3_exp_q)) : s3_mant_q;

    // 2. Instantiate the GRS rounder.
    wire [MANT_W:0] rounded_mant_w_implicit;
    wire            rounder_overflow;
    grs_rounder #(
        .INPUT_WIDTH(2*MANT_W + 1),
        .OUTPUT_WIDTH(MANT_W + 1) // Keep implicit bit for overflow check
    ) u_rounder (
        .value_in(mant_to_round),
        .sign_in(s3_sign_q),
        .mode(round_mode),
        .value_out(rounded_mant_w_implicit),
        .overflow_out(rounder_overflow)
    );

    // 3. Calculate the final exponent after rounding.
    // wire signed [EXP_W+1:0] final_exp_rounded = s3_exp_q + $signed({{(EXP_W+1){1'b0}},rounder_overflow});
    wire signed [EXP_W+1:0] final_exp_rounded = s3_exp_q + rounder_overflow;

    // 4. Pack the final result based on all conditions.
    reg [EXP_W-1:0] out_exp;
    reg [MANT_W-1:0] out_mant;
    always @(*) begin
        // Check for overflow/underflow on the exponent *before* rounding.
        if (final_exp_rounded >= $signed({2'b00, EXP_ALL_ONES})) begin // Pre-round overflow -> Infinity
            out_exp = EXP_ALL_ONES;
            out_mant = MANT_ALL_ZEROS;
        end else if (is_underflow) begin // Underflow -> Denormalized or Zero
            // After rounding a denormalized number, it's possible it rounds
            // back up to the smallest normal number.
            if (final_exp_rounded > $signed({(EXP_W+2){1'b0}})) begin
                out_exp = 1;
                out_mant = MANT_ALL_ZEROS; // Smallest normal number
            end else begin
                out_exp = EXP_ALL_ZEROS;
                out_mant = rounded_mant_w_implicit[MANT_W-1:0];
            end
        end else begin // Normal number
            // The result is a normal number.
            out_exp = final_exp_rounded[EXP_W-1:0];
            out_mant = rounded_mant_w_implicit[MANT_W-1:0];
        end
    end

    reg [WIDTH-1:0] result_d;
    always @(*) begin
        if (s3_special_case_q) begin
            // Special cases (NaN, Inf, Zero) bypass all rounding and packing logic.
            result_d = s3_special_result_q;
        end else begin
            result_d = {s3_sign_q, out_exp, out_mant};
        end
    end

    reg [WIDTH-1:0] result_q;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result_q <= P_ZERO;
        end else begin
            result_q <= result_d;
        end
    end

    // Assign final registered output
    assign result = result_q;

endmodule
