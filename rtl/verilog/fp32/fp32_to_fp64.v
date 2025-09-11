// fp32_to_fp64.v
//
// Verilog RTL to convert a 32-bit float to a 64-bit float.
//
// Features:
// - Refactored to use fp32_classify for special case handling.
// - Uses simple, sequential assignments for better compiler compatibility.

module fp32_to_fp64 (
    input  [31:0] fp32_in,
    output reg [63:0] fp64_out
);

    //==================================================================
    // 1. Classification of the FP32 Input
    //==================================================================
    wire is_snan, is_qnan, is_neg_inf, is_pos_inf, is_neg_norm, is_pos_norm,
         is_neg_denorm, is_pos_denorm, is_neg_zero, is_pos_zero;

    fp32_classify classifier (
        .in(fp32_in),
        .is_snan(is_snan), .is_qnan(is_qnan),
        .is_neg_inf(is_neg_inf), .is_pos_inf(is_pos_inf),
        .is_neg_norm(is_neg_norm), .is_pos_norm(is_pos_norm),
        .is_neg_denorm(is_neg_denorm), .is_pos_denorm(is_pos_denorm),
        .is_neg_zero(is_neg_zero), .is_pos_zero(is_pos_zero)
    );

    wire is_nan = is_snan || is_qnan;
    wire is_inf = is_pos_inf || is_neg_inf;
    wire is_zero = is_pos_zero || is_neg_zero;
    wire is_denorm = is_pos_denorm || is_neg_denorm;

    //==================================================================
    // 2. Unpack FP32 components
    //==================================================================
    wire sign_in = fp32_in[31];
    wire [7:0] exp32 = fp32_in[30:23];
    wire [22:0] mant32 = fp32_in[22:0];

    //==================================================================
    // 3. Conversion Logic
    //==================================================================
    integer shift_amount;
    reg [22:0] temp_mant;
    reg [10:0] exp64;
    reg [51:0] mant64;
    reg [22:0] normalized_mant32;
    always @(*) begin
        if (is_nan) begin
            // Propagate NaN, making it a quiet NaN in 64-bit format
            mant64 = {mant32, 29'b0};
            mant64[51] = 1'b1; // Set MSb of mantissa to indicate qNaN
            fp64_out = {sign_in, 11'h7FF, mant64};
        end
        else if (is_inf) begin
            fp64_out = {sign_in, 11'h7FF, 52'b0};
        end
        else if (is_zero) begin
            fp64_out = {sign_in, 63'b0};
        end
        else if (is_denorm) begin
            // Normalize the denormalized 32-bit number

            temp_mant = mant32;
            shift_amount = 0;
            // This is a priority encoder
            if      (temp_mant[22]) shift_amount = 0;
            else if (temp_mant[21]) shift_amount = 1;
            else if (temp_mant[20]) shift_amount = 2;
            else if (temp_mant[19]) shift_amount = 3;
            else if (temp_mant[18]) shift_amount = 4;
            else if (temp_mant[17]) shift_amount = 5;
            else if (temp_mant[16]) shift_amount = 6;
            else if (temp_mant[15]) shift_amount = 7;
            else if (temp_mant[14]) shift_amount = 8;
            else if (temp_mant[13]) shift_amount = 9;
            else if (temp_mant[12]) shift_amount = 10;
            else if (temp_mant[11]) shift_amount = 11;
            else if (temp_mant[10]) shift_amount = 12;
            else if (temp_mant[9])  shift_amount = 13;
            else if (temp_mant[8])  shift_amount = 14;
            else if (temp_mant[7])  shift_amount = 15;
            else if (temp_mant[6])  shift_amount = 16;
            else if (temp_mant[5])  shift_amount = 17;
            else if (temp_mant[4])  shift_amount = 18;
            else if (temp_mant[3])  shift_amount = 19;
            else if (temp_mant[2])  shift_amount = 20;
            else if (temp_mant[1])  shift_amount = 21;
            else if (temp_mant[0])  shift_amount = 22;

            // Shift mantissa left to remove leading zeros (and implicit 1)
            normalized_mant32 = temp_mant << (shift_amount + 1);
            
            // Pad to the right to form the 52-bit mantissa
            mant64 = {normalized_mant32, 29'b0};
            
            // Calculate new exponent: fp64_bias - fp32_bias - shift
            exp64 = 1023 - 126 - shift_amount;
            
            fp64_out = {sign_in, exp64, mant64};
        end
        else begin // Normal conversion

            // Re-bias the exponent: new_exp = old_exp - old_bias + new_bias
            exp64 = exp32 - 127 + 1023;
            
            // Pad mantissa to the right
            mant64 = {mant32, 29'b0};
            
            fp64_out = {sign_in, exp64, mant64};
        end
    end

endmodule
