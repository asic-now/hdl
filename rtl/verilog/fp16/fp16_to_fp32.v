// rtl/verilog/fp16/fp16_to_fp32.v
//
// Converts a 16-bit half-precision float to a 32-bit single-precision float.
//
// Features:
// - Refactored to use fp16_classify for special case handling.
// - Uses simple, sequential assignments for better compiler compatibility.

module fp16_to_fp32 (
    input  [15:0] fp16_in,
    output reg [31:0] fp32_out
);

    //==================================================================
    // 1. Classification of the FP16 Input
    //==================================================================
    wire is_snan, is_qnan, is_neg_inf, is_pos_inf, is_neg_norm, is_pos_norm,
         is_neg_denorm, is_pos_denorm, is_neg_zero, is_pos_zero;

    fp16_classify classifier (
        .in(fp16_in),
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
    // 2. Unpack FP16 components
    //==================================================================
    wire sign_in = fp16_in[15];
    wire [4:0] exp_in = fp16_in[14:10];
    wire [9:0] mant_in = fp16_in[9:0];

    //==================================================================
    // 3. Conversion Logic
    //==================================================================
    integer shift_amount;
    reg [ 7:0] exp32;
    reg [22:0] mant32;
    always @(*) begin
        if (is_nan) begin
            // Propagate NaN, converting to a 32-bit qNaN representation.
            // Payload (mantissa) is preserved in the MSBs.
            fp32_out = {sign_in, 8'hFF, mant_in, 13'b0};
            fp32_out[22] = 1'b1; // Ensure it's a quiet NaN
        end
        else if (is_inf) begin
            // Propagate infinity.
            fp32_out = {sign_in, 8'hFF, 23'b0};
        end
        else if (is_zero) begin
            // Propagate zero.
            fp32_out = {sign_in, 31'b0};
        end
        else if (is_denorm) begin
            // A denormalized fp16 becomes a normalized fp32.
            // Find the first '1' in the mantissa to calculate the new exponent.
            shift_amount = 0;
            // This is a priority encoder.
            // for(integer i=9; i>=0; i=i-1) begin
            //     if(mant_in[i]) begin
            //         shift_amount = 9 - i;
            //         break; // for
            //     end
            // end
            if (mant_in[9]) shift_amount = 0;
            else if (mant_in[8]) shift_amount = 1;
            else if (mant_in[7]) shift_amount = 2;
            else if (mant_in[6]) shift_amount = 3;
            else if (mant_in[5]) shift_amount = 4;
            else if (mant_in[4]) shift_amount = 5;
            else if (mant_in[3]) shift_amount = 6;
            else if (mant_in[2]) shift_amount = 7;
            else if (mant_in[1]) shift_amount = 8;
            else if (mant_in[0]) shift_amount = 9;

            // Shift mantissa left to normalize it, then pad with zeros.
            mant32 = {mant_in, 13'b0} << (shift_amount + 1);
            
            // Calculate the new biased exponent.
            // fp16 denorm exp = -14. fp32 bias = 127. New exp = 127 - 14 - shift.
            exp32 = 127 - 14 - shift_amount;
            
            fp32_out = {sign_in, exp32, mant32};
        end
        else begin // Is a normal number
            // Normal conversion

            // Adjust exponent for the new bias. (127 - 15 = 112)
            exp32 = exp_in + 112;
            
            // Pad the mantissa with zeros to the right.
            mant32 = {mant_in, 13'b0};

            fp32_out = {sign_in, exp32, mant32};
        end
    end

endmodule
