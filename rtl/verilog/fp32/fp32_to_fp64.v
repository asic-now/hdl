// fp32_to_fp64.v
//
// Verilog RTL to convert a 32-bit float to a 64-bit float.
//
// Features:
// - Combinational logic.
// - Handles NaN, Infinity, Zero, and denormalized numbers.

module fp32_to_fp64 (
    input  [31:0] fp32_in,
    output reg [63:0] fp64_out
);

    // Unpack 32-bit input
    wire sign = fp32_in[31];
    wire [7:0] exp32 = fp32_in[30:23];
    wire [22:0] mant32 = fp32_in[22:0];

    // Detect special 32-bit values
    wire is_nan32 = (exp32 == 8'hFF) && (mant32 != 0);
    wire is_inf32 = (exp32 == 8'hFF) && (mant32 == 0);
    wire is_zero32 = (exp32 == 0) && (mant32 == 0);
    wire is_denorm32 = (exp32 == 0) && (mant32 != 0);

    integer shift_amount;
    reg [22:0] temp_mant;
    reg [10:0] exp64;
    reg [51:0] mant64;
    always @(*) begin
        if (is_nan32) begin
            // Propagate NaN, making it a quiet NaN in 64-bit format
            fp64_out = {sign, 11'h7FF, {1'b1, mant32, 28'b0}};
        end else if (is_inf32) begin
            fp64_out = {sign, 11'h7FF, 52'b0};
        end else if (is_zero32) begin
            fp64_out = {sign, 63'b0};
        end else if (is_denorm32) begin
            // Normalize the denormalized 32-bit number
            temp_mant = mant32;
            
            shift_amount = 0;
            for(integer i=22; i>=0; i=i-1) begin
                if(temp_mant[i]) shift_amount = 22 - i;
            end
            
            exp64 = 1023 - 127 - shift_amount;
            mant64 = (temp_mant << (shift_amount + 1))[22:0] << 29;
            fp64_out = {sign, exp64, mant64};
        end else begin
            // Normal conversion
            exp64 = exp32 - 127 + 1023;
            mant64 = {mant32, 29'b0}; // Pad mantissa
            fp64_out = {sign, exp64, mant64};
        end
    end

endmodule
