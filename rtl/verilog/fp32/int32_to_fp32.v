// rtl/verilog/fp32/int32_to_fp32.v
//
// Verilog RTL to convert a 32-bit signed integer to a 32-bit float.
//
// Features:
// - Combinational logic.
// - Handles zero and negative numbers.
// - Uses a priority encoder to find the MSB for normalization.

module int32_to_fp32 (
    input  [31:0] int_in,
    output reg [31:0] fp_out
);

    integer msb_pos;
    reg sign;
    reg [31:0] abs_val;
    reg [ 7:0] out_exp;
    reg [22:0] out_mant;
    reg [31:0] shifted_mant;
    always @(*) begin
        if (int_in == 32'd0) begin
            fp_out = 32'd0;
        end else begin
            // Get sign and absolute value
            if (int_in[31]) begin
                sign = 1'b1;
                abs_val = -int_in;
            end else begin
                sign = 1'b0;
                abs_val = int_in;
            end

            // Priority encode to find MSB
            msb_pos = 0;
            for (integer i = 30; i >= 0; i = i - 1) begin
                if (abs_val[i]) begin
                    msb_pos = i;
                end
            end

            // Calculate exponent and mantissa

            out_exp = msb_pos + 127;
            
            // Shift to remove implicit bit and align for mantissa
            shifted_mant = abs_val << (31 - msb_pos);
            out_mant = shifted_mant[30:8];

            fp_out = {sign, out_exp, out_mant};
        end
    end

endmodule
