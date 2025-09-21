// rtl/verilog/fp16/int16_to_fp16.v
//
// Verilog RTL to convert a 16-bit signed integer to a 16-bit float.
//
// Features:
// - Combinational logic.
// - Handles zero and negative numbers.
// - Uses a priority encoder to find the MSB for normalization.

module int16_to_fp16 (
    input  [15:0] int_in,
    output reg [15:0] fp_out
);

    integer msb_pos;
    reg sign;
    reg [15:0] abs_val;
    reg [4:0] out_exp;
    reg [9:0] out_mant;
    reg [15:0] shifted_mant;
    always @(*) begin
        if (int_in == 16'd0) begin
            fp_out = `FP16_ZERO;
        end else begin
            // Get sign and absolute value
            if (int_in[15]) begin
                sign = 1'b1;
                abs_val = -int_in;
            end else begin
                sign = 1'b0;
                abs_val = int_in;
            end

            // Priority encode to find MSB
            msb_pos = 0;
            for (integer i = 14; i >= 0; i = i - 1) begin
                if (abs_val[i]) begin
                    msb_pos = i;
                end
            end

            // Calculate exponent and mantissa
            out_exp = msb_pos + 15;
            
            // Shift to remove implicit bit and align for mantissa
            shifted_mant = abs_val << (15 - msb_pos);
            out_mant = shifted_mant[14:5];

            fp_out = {sign, out_exp, out_mant};
        end
    end

endmodule
