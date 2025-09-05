// int64_to_fp64.v
//
// Verilog RTL to convert a 64-bit signed integer to a 64-bit float.
//
// Features:
// - Combinational logic.
// - Handles zero and negative numbers.
// - Uses a priority encoder to find the MSB for normalization.

module int64_to_fp64 (
    input  [63:0] int_in,
    output reg [63:0] fp_out
);

    always @(*) begin
        if (int_in == 64'd0) begin
            fp_out = 64'd0;
        end else begin
            // Get sign and absolute value
            reg sign;
            reg [63:0] abs_val;
            if (int_in[63]) begin
                sign = 1'b1;
                abs_val = -int_in;
            end else begin
                sign = 1'b0;
                abs_val = int_in;
            end

            // Priority encode to find MSB
            integer msb_pos;
            msb_pos = 0;
            for (integer i = 62; i >= 0; i = i - 1) begin
                if (abs_val[i]) begin
                    msb_pos = i;
                end
            end

            // Calculate exponent and mantissa
            reg [10:0] out_exp;
            reg [51:0] out_mant;
            reg [63:0] shifted_mant;

            out_exp = msb_pos + 1023;
            
            // Shift to remove implicit bit and align for mantissa
            shifted_mant = abs_val << (63 - msb_pos);
            out_mant = shifted_mant[62:11];

            fp_out = {sign, out_exp, out_mant};
        end
    end

endmodule
