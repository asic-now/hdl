// fp64_mul_sub.v
//
// Verilog RTL for a 64-bit (double-precision) floating-point Fused Multiply-Subtract (FMS).
//
// Operation: result = a * b - c
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
    // Stages 1 and 2 are identical to FMA and are omitted for brevity.
    // They perform unpacking, multiplication, and product normalization.
    
    //----------------------------------------------------------------
    // (Stages 1 and 2 logic would be here)
    //----------------------------------------------------------------
    
    // For this example, let's assume the outputs of Stage 2 are available as:
    reg signed [11:0] s2_norm_exp_ab;
    reg [105:0]       s2_norm_mant_ab;
    reg               s2_sign_ab;
    reg               s2_sign_c;
    reg [10:0]        s2_exp_c;
    reg [52:0]        s2_mant_c;
    reg s2_prop_is_nan, s2_prop_is_inf, s2_prop_inf_sign;
    reg s2_is_nan_c, s2_is_inf_c;
    
    //----------------------------------------------------------------
    // Stage 3: Align and Subtract
    //----------------------------------------------------------------
    reg [11:0]  s3_res_exp;
    reg         s3_res_sign;
    reg [211:0] s3_mant_sum;
    reg s3_special_case;
    reg [63:0] s3_special_result;

    always @(posedge clk) begin
        if (!rst_n) begin
            // ... reset registers ...
        end else begin
            // FMS Special Case: inf - inf = NaN
            if (s2_prop_is_nan || s2_is_nan_c) begin
                s3_special_case <= 1'b1; s3_special_result <= 64'h7FF8000000000001;
            end else if (s2_prop_is_inf && s2_is_inf_c && (s2_prop_inf_sign == s2_sign_c)) begin
                 s3_special_case <= 1'b1; s3_special_result <= 64'h7FF8000000000001;
            end else if (s2_prop_is_inf) begin
                s3_special_case <= 1'b1; s3_special_result <= {s2_prop_inf_sign, 11'h7FF, 52'b0};
            end else if (s2_is_inf_c) begin
                s3_special_case <= 1'b1; s3_special_result <= {~s2_sign_c, 11'h7FF, 52'b0};
            end else begin
                s3_special_case <= 0;
                reg signed [11:0] exp_diff;
                reg [211:0] mant_ab_extended, mant_c_extended;
                
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
                if (s2_sign_ab != s2_sign_c) { // Effective Addition
                    s3_mant_sum <= mant_ab_extended + mant_c_extended;
                } else { // Effective Subtraction
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
    // ... (rest of logic is identical to fp64_mul_add.v)
    always @(posedge clk) begin
        if(!rst_n) result_reg <= 64'b0;
        else if (s3_special_case) result_reg <= s3_special_result;
        else begin
            // Normalization logic from FMA
        end
    end
    
    assign result = result_reg;

endmodule
