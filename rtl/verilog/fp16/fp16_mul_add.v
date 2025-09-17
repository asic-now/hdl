// fp16_mul_add.v
//
// Verilog RTL for a 16-bit (half-precision) floating-point Fused Multiply-Accumulate (FMA).
//
// Operation: result = a * b + c
//
// Format (IEEE 754 half-precision):
// [   15]: Sign bit (1 for negative, 0 for positive)
// [14:10]: 5-bit exponent (bias of 15)
// [ 9: 0]: 10-bit mantissa (fraction/significand)
//
// Features:
// - 4-stage pipelined architecture.
// - Fused operation for higher precision.
// - Handles normalized and denormalized numbers.
// - Handles all special cases (NaN, Infinity, Zero).
// - Truncates the result (no rounding). // TODO: rounding.

module fp16_mul_add (
    input clk,
    input rst_n,

    input  [15:0] a,
    input  [15:0] b,
    input  [15:0] c,

    output [15:0] result
);

    //----------------------------------------------------------------
    // Stage 1: Unpack and Initial Calculations
    //----------------------------------------------------------------
    
    // Unpack all three inputs
    wire       sign_a = a[15], sign_b = b[15], sign_c = c[15];
    wire [4:0] exp_a  = a[14:10], exp_b = b[14:10], exp_c = c[14:10];
    wire [9:0] mant_a = a[9:0], mant_b = b[9:0], mant_c = c[9:0];

    // Detect special values for all three inputs
    wire is_nan_a = (exp_a == 5'h1F) && (mant_a != 0);
    wire is_inf_a = (exp_a == 5'h1F) && (mant_a == 0);
    wire is_zero_a = (exp_a == 0) && (mant_a == 0);
    wire is_nan_b = (exp_b == 5'h1F) && (mant_b != 0);
    wire is_inf_b = (exp_b == 5'h1F) && (mant_b == 0);
    wire is_zero_b = (exp_b == 0) && (mant_b == 0);
    wire is_nan_c = (exp_c == 5'h1F) && (mant_c != 0);
    wire is_inf_c = (exp_c == 5'h1F) && (mant_c == 0);
    wire is_zero_c = (exp_c == 0) && (mant_c == 0);

    // Add implicit leading bit
    wire [10:0] full_mant_a = {(exp_a != 0), mant_a};
    wire [10:0] full_mant_b = {(exp_b != 0), mant_b};
    wire [10:0] full_mant_c = {(exp_c != 0), mant_c};

    wire [ 5:0] effective_exp_a = (exp_a == 0) ? 1 : exp_a;
    wire [ 5:0] effective_exp_b = (exp_b == 0) ? 1 : exp_b;

    // Stage 1 pipeline registers
    reg signed [ 5:0] s1_product_exp_sum;
    reg               s1_product_sign;
    reg        [10:0] s1_mant_a, s1_mant_b;

    reg               s1_sign_c;
    reg        [ 4:0] s1_exp_c;
    reg        [10:0] s1_mant_c;

    // Propagate special case flags
    reg s1_is_nan_a, s1_is_inf_a, s1_is_zero_a;
    reg s1_is_nan_b, s1_is_inf_b, s1_is_zero_b;
    reg s1_is_nan_c, s1_is_inf_c, s1_is_zero_c;

    always @(posedge clk) begin
        if (!rst_n) begin
            s1_product_exp_sum <= 0;
            s1_product_sign <= 0;
            s1_mant_a <= 0;
            s1_mant_b <= 0;
            s1_sign_c <= 0;
            s1_exp_c <= 0;
            s1_mant_c <= 0;
            s1_is_nan_a <= 0; s1_is_inf_a <= 0; s1_is_zero_a <= 0;
            s1_is_nan_b <= 0; s1_is_inf_b <= 0; s1_is_zero_b <= 0;
            s1_is_nan_c <= 0; s1_is_inf_c <= 0; s1_is_zero_c <= 0;
        end else begin
            // Product (a*b) preliminary calculations
            s1_product_exp_sum <= effective_exp_a + effective_exp_b - 15;
            s1_product_sign <= sign_a ^ sign_b;
            s1_mant_a <= full_mant_a;
            s1_mant_b <= full_mant_b;

            // Pass 'c' through
            s1_sign_c <= sign_c;
            s1_exp_c <= exp_c;
            s1_mant_c <= full_mant_c;

            // Pass flags through
            s1_is_nan_a <= is_nan_a; s1_is_inf_a <= is_inf_a; s1_is_zero_a <= is_zero_a;
            s1_is_nan_b <= is_nan_b; s1_is_inf_b <= is_inf_b; s1_is_zero_b <= is_zero_b;
            s1_is_nan_c <= is_nan_c; s1_is_inf_c <= is_inf_c; s1_is_zero_c <= is_zero_c;
        end
    end

    //----------------------------------------------------------------
    // Stage 2: Mantissa Multiplication and Product Normalization
    //----------------------------------------------------------------
    // Mantissa multiplication
    wire [21:0] mant_product = s1_mant_a * s1_mant_b;

    reg signed [ 5:0] s2_norm_exp_ab;
    reg        [21:0] s2_norm_mant_ab;
    reg               s2_sign_ab;
    
    reg               s2_sign_c;
    reg        [ 4:0] s2_exp_c;
    reg        [10:0] s2_mant_c;
    
    reg s2_prop_is_nan, s2_prop_is_inf, s2_prop_inf_sign;
    reg s2_ab_is_zero;
    reg s2_is_nan_c, s2_is_inf_c, s2_is_zero_c;

    always @(posedge clk) begin
        if (!rst_n) begin
            // TODO: reset registers (optional by param)
        end else begin
            // Normalize the product
            if (mant_product[21]) begin // Result is 1x.f..., shift right
                s2_norm_exp_ab <= s1_product_exp_sum + 1;
                s2_norm_mant_ab <= mant_product; // Keep full precision
            end else begin // Result is 01.f...
                s2_norm_exp_ab <= s1_product_exp_sum;
                s2_norm_mant_ab <= mant_product << 1; // Normalize to 1.f
            end
            s2_sign_ab <= s1_product_sign;
            s2_ab_is_zero <= s1_is_zero_a || s1_is_zero_b;

            // Propagate 'c' and special flags
            s2_sign_c <= s1_sign_c;
            s2_exp_c <= s1_exp_c;
            s2_mant_c <= s1_mant_c;
            s2_is_nan_c <= s1_is_nan_c; s2_is_inf_c <= s1_is_inf_c; s2_is_zero_c <= s1_is_zero_c;

            // Evaluate special cases for the product (a*b)
            s2_prop_is_nan <= s1_is_nan_a || s1_is_nan_b || (s1_is_inf_a && s1_is_zero_b) || (s1_is_zero_a && s1_is_inf_b);
            s2_prop_is_inf <= s1_is_inf_a || s1_is_inf_b;
            s2_prop_inf_sign <= s1_product_sign;
        end
    end
    
    //----------------------------------------------------------------
    // Stage 3: Align and Add
    //----------------------------------------------------------------
    reg [ 5:0] s3_res_exp;
    reg        s3_res_sign;
    reg [47:0] s3_mant_sum; // Wide mantissa for calculation
    
    reg        s3_special_case;
    reg [15:0] s3_special_result;
    reg signed [5:0] exp_diff;
    reg [47:0] mant_ab_extended, mant_c_extended;
    always @(posedge clk) begin
        if (!rst_n) begin
            // TODO: reset registers
        end else begin
            // Logic to handle special case propagation before alignment
            if (s2_prop_is_nan || s2_is_nan_c) begin
                s3_special_case <= 1'b1;
                s3_special_result <= `FP16_SNAN; // NaN
            end else if (s2_prop_is_inf && s2_is_inf_c && (s2_prop_inf_sign != s2_sign_c)) begin
                 s3_special_case <= 1'b1;
                 s3_special_result <= `FP16_SNAN; // Inf - Inf = NaN
            end else if (s2_prop_is_inf) begin
                s3_special_case <= 1'b1;
                s3_special_result <= {s2_prop_inf_sign, 5'h1F, 10'b0};
            end else if (s2_is_inf_c) begin
                s3_special_case <= 1'b1;
                s3_special_result <= {s2_sign_c, 5'h1F, 10'b0};
            end else if (s2_ab_is_zero) begin // a*b is zero, result is just c
                s3_special_case <= 1'b1;
                s3_special_result <= {s2_sign_c, s2_exp_c, s2_mant_c[9:0]};
            end else if (s2_is_zero_c) begin // c is zero, result is a*b (needs normalization)
                s3_special_case <= 0; // Let it fall through to stage 4 for packing
                s3_mant_sum <= {s2_norm_mant_ab, 26'b0}; // pack a*b into adder bus
                s3_res_exp <= s2_norm_exp_ab;
                s3_res_sign <= s2_sign_ab;
            end else begin
                // Normal path: Align and add/subtract
                s3_special_case <= 0;
                
                if(s2_norm_exp_ab >= s2_exp_c) begin
                    s3_res_exp <= s2_norm_exp_ab;
                    s3_res_sign <= s2_sign_ab;
                    exp_diff <= s2_norm_exp_ab - s2_exp_c;
                    mant_ab_extended = {s2_norm_mant_ab, 26'b0};
                    mant_c_extended = {s2_mant_c, 37'b0} >> exp_diff;
                end else begin
                    s3_res_exp <= s2_exp_c;
                    s3_res_sign <= s2_sign_c;
                    exp_diff <= s2_exp_c - s2_norm_exp_ab;
                    mant_ab_extended = {s2_norm_mant_ab, 26'b0} >> exp_diff;
                    mant_c_extended = {s2_mant_c, 37'b0};
                end

                if (s2_sign_ab == s3_res_sign) begin // Add magnitudes
                    s3_mant_sum <= mant_ab_extended + mant_c_extended;
                end else begin // Subtract magnitudes
                    s3_mant_sum <= mant_ab_extended - mant_c_extended;
                end
            end
        end
    end

    //----------------------------------------------------------------
    // Stage 4: Normalize and Pack
    //----------------------------------------------------------------
    reg [15:0] result_reg;

    integer shift_amount;
    reg  signed [ 6:0] final_exp;
    reg         [47:0] final_mant;
    reg         [ 9:0] out_mant;
    reg         [ 4:0] out_exp;
    always @(posedge clk) begin
        if(!rst_n) begin
            result_reg <= `FP16_ZERO;
        end else begin
            if (s3_special_case) begin
                result_reg <= s3_special_result;
            end else begin
                final_exp = s3_res_exp;
                final_mant = s3_mant_sum;

                if (final_mant == 0) begin
                    final_exp = 0;
                end else if (final_mant[47]) begin // Overflow from add
                    final_exp = final_exp + 1;
                    final_mant = final_mant >> 1;
                end else if (final_mant[46] == 0) begin // Normalize after sub
                    shift_amount = 0;
                    for (integer i = 46; i >= 0; i = i - 1) begin
                        if (final_mant[i]) begin
                            shift_amount = 46 - i;
                        end
                    end
                    final_mant = final_mant << shift_amount;
                    final_exp = final_exp - shift_amount;
                end

                // Pack final result

                out_mant = final_mant[45:36];

                if (final_exp >= 31) begin // Overflow -> Inf
                    out_exp = 5'h1F; out_mant = 10'b0;
                end else if (final_exp <= 0) begin // Underflow -> Denormalized/Zero
                    out_mant = ({1'b1, final_mant[45:0]}) >> (1 - final_exp);
                    out_exp = 5'b0;
                end else begin
                    out_exp = final_exp[4:0];
                end
                
                if (out_exp == 0 && out_mant == 0) begin
                    result_reg <= {s3_res_sign, 15'b0};
                end else begin
                    result_reg <= {s3_res_sign, out_exp, out_mant};
                end
            end
        end
    end

    assign result = result_reg;

endmodule
