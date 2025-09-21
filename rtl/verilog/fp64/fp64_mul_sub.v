// rtl/verilog/fp64/fp64_mul_sub.v
//
// Verilog RTL for a 64-bit (double-precision) floating-point Fused Multiply-Subtract (FMS).
//
// Operation: result = a * b - c
//
// Format (IEEE 754 double-precision):
// [63]   : Sign bit
// [62:52]: 11-bit exponent (bias of 1023)
// [51:0] : 52-bit mantissa
//
// Features:
// - 4-stage pipelined architecture.
// - Fused operation for higher precision.
// - Handles all special cases (NaN, Infinity, Zero).

module fp64_mul_sub (
    input clk,
    input rst_n,

    input  [63:0] a,
    input  [63:0] b,
    input  [63:0] c,

    output [63:0] result
);

    //----------------------------------------------------------------
    // Stage 1: Unpack and Initial Calculations
    //----------------------------------------------------------------
    
    // Unpack all three inputs
    wire        sign_a = a[63], sign_b = b[63], sign_c = c[63];
    wire [10:0] exp_a  = a[62:52], exp_b = b[62:52], exp_c = c[62:52];
    wire [51:0] mant_a = a[51:0], mant_b = b[51:0], mant_c = c[51:0];

    // Detect special values for all three inputs
    wire is_nan_a = (exp_a == 11'h7FF) && (mant_a != 0);
    wire is_inf_a = (exp_a == 11'h7FF) && (mant_a == 0);
    wire is_zero_a = (exp_a == 0) && (mant_a == 0);
    wire is_nan_b = (exp_b == 11'h7FF) && (mant_b != 0);
    wire is_inf_b = (exp_b == 11'h7FF) && (mant_b == 0);
    wire is_zero_b = (exp_b == 0) && (mant_b == 0);
    wire is_nan_c = (exp_c == 11'h7FF) && (mant_c != 0);
    wire is_inf_c = (exp_c == 11'h7FF) && (mant_c == 0);
    wire is_zero_c = (exp_c == 0) && (mant_c == 0);

    // Add implicit leading bit
    wire [52:0] full_mant_a = {(exp_a != 0), mant_a};
    wire [52:0] full_mant_b = {(exp_b != 0), mant_b};
    wire [52:0] full_mant_c = {(exp_c != 0), mant_c};

    wire [11:0] effective_exp_a = (exp_a == 0) ? 1 : exp_a;
    wire [11:0] effective_exp_b = (exp_b == 0) ? 1 : exp_b;

    // Stage 1 pipeline registers
    reg signed [11:0] s1_product_exp_sum;
    reg               s1_product_sign;
    reg        [52:0] s1_mant_a, s1_mant_b;

    reg               s1_sign_c;
    reg        [10:0] s1_exp_c;
    reg        [52:0] s1_mant_c;

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
            s1_product_exp_sum <= effective_exp_a + effective_exp_b - 1023;
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
    wire [105:0] mant_product = s1_mant_a * s1_mant_b;

    reg signed [ 11:0] s2_norm_exp_ab;
    reg        [105:0] s2_norm_mant_ab;
    reg                s2_sign_ab;
    
    reg                s2_sign_c;
    reg        [ 10:0] s2_exp_c;
    reg        [ 52:0] s2_mant_c;
    
    reg s2_prop_is_nan, s2_prop_is_inf, s2_prop_inf_sign;
    reg s2_ab_is_zero;
    reg s2_is_nan_c, s2_is_inf_c, s2_is_zero_c;

    always @(posedge clk) begin
        if (!rst_n) begin
            // TODO: (when needed) reset registers (optional by param)
        end else begin
            // Normalize the product
            if (mant_product[105]) begin // Result is 1x.f..., shift right
                s2_norm_exp_ab <= s1_product_exp_sum + 1;
                s2_norm_mant_ab <= mant_product >> 1; 
            end else begin // Result is 01.f...
                s2_norm_exp_ab <= s1_product_exp_sum;
                s2_norm_mant_ab <= mant_product;
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
    // Stage 3: Align and Subtract
    //----------------------------------------------------------------
    reg [ 11:0] s3_res_exp;
    reg         s3_res_sign;
    reg [211:0] s3_mant_sum;
    reg         s3_special_case;
    reg [ 63:0] s3_special_result;

    reg signed [ 11:0] exp_diff;
    reg        [211:0] mant_ab_extended, mant_c_extended;
    always @(posedge clk) begin
        if (!rst_n) begin
            // TODO: (when needed) reset registers
        end else begin
            // FMS Special Case: inf - inf = NaN
            if (s2_prop_is_nan || s2_is_nan_c) begin
                s3_special_case <= 1'b1;
                s3_special_result <= 64'h7FF8000000000001;
            end else if (s2_prop_is_inf && s2_is_inf_c && (s2_prop_inf_sign == s2_sign_c)) begin
                s3_special_case <= 1'b1;
                s3_special_result <= 64'h7FF8000000000001;
            end else if (s2_prop_is_inf) begin
                s3_special_case <= 1'b1;
                s3_special_result <= {s2_prop_inf_sign, 11'h7FF, 52'b0};
            end else if (s2_is_inf_c) begin
                s3_special_case <= 1'b1;
                s3_special_result <= {~s2_sign_c, 11'h7FF, 52'b0};
            end else begin
                s3_special_case <= 0;
                
                if(s2_norm_exp_ab >= s2_exp_c) begin
                    s3_res_exp <= s2_norm_exp_ab;
                    s3_res_sign <= s2_sign_ab;
                    exp_diff <= s2_norm_exp_ab - s2_exp_c;
                    mant_ab_extended = {s2_norm_mant_ab, 106'b0};
                    mant_c_extended = {s2_mant_c, 159'b0} >> exp_diff;
                end else begin
                    s3_res_exp <= s2_exp_c;
                    s3_res_sign <= ~s2_sign_c;
                    exp_diff <= s2_exp_c - s2_norm_exp_ab;
                    mant_ab_extended = {s2_norm_mant_ab, 106'b0} >> exp_diff;
                    mant_c_extended = {s2_mant_c, 159'b0};
                end

                // Invert adder logic for FMS
                if (s2_sign_ab != s2_sign_c) begin // Effective Addition
                    s3_mant_sum <= mant_ab_extended + mant_c_extended;
                end else begin // Effective Subtraction
                    if (mant_ab_extended >= mant_c_extended) begin
                       s3_mant_sum <= mant_ab_extended - mant_c_extended;
                    end else begin
                       s3_mant_sum <= mant_c_extended - mant_ab_extended;
                       s3_res_sign <= ~s3_res_sign;
                    end
                end
            end
        end
    end

    //----------------------------------------------------------------
    // Stage 4: Normalize and Pack (Identical to FMA)
    //----------------------------------------------------------------
    reg [63:0] result_reg;

    integer shift_amount;
    reg signed [ 12:0] final_exp;
    reg        [211:0] final_mant;
    reg        [ 51:0] out_mant;
    reg        [ 10:0] out_exp;
    always @(posedge clk) begin
        if (!rst_n) begin
            result_reg <= 64'b0;
        end else begin
            if (s3_special_case) begin
                result_reg <= s3_special_result;
            end else begin
                final_exp = s3_res_exp;
                final_mant = s3_mant_sum;

                if (final_mant == 0) begin
                    final_exp = 0;
                end else if (final_mant[211]) begin // Overflow from add
                    final_exp = final_exp + 1;
                    final_mant = final_mant >> 1;
                end else if (final_mant[210] == 0) begin // Normalize after sub
                    shift_amount = 0;
                    for (integer i = 210; i >= 0; i = i - 1) begin
                        if (final_mant[i]) begin
                            shift_amount = 210 - i;
                        end
                    end
                    final_mant = final_mant << shift_amount;
                    final_exp = final_exp - shift_amount;
                end

                // Pack final result

                out_mant = final_mant[209:158];

                if (final_exp >= 2047) begin // Overflow -> Inf
                    out_exp = 11'h7FF; out_mant = 52'b0;
                end else if (final_exp <= 0) begin // Underflow -> Denormalized/Zero
                    out_mant = ({1'b1, final_mant[209:0]}) >> (1 - final_exp);
                    out_exp = 11'b0;
                end else begin
                    out_exp = final_exp[10:0];
                end
                
                if (out_exp == 0 && out_mant == 0) begin
                    result_reg <= {s3_res_sign, 63'b0};
                end else begin
                    result_reg <= {s3_res_sign, out_exp, out_mant};
                end
            end
        end
    end

    assign result = result_reg;

endmodule
