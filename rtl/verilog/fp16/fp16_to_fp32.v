// fp16_to_fp32.v
//
// Verilog RTL to convert a 16-bit float to a 32-bit float.
//
// Features:
// - Combinational logic.
// - Handles NaN, Infinity, Zero, and denormalized numbers.

module fp16_to_fp32 (
    input  [15:0] fp16_in,
    output reg [31:0] fp32_out
);

    // Unpack 16-bit input
    wire sign = fp16_in[15];
    wire [4:0] exp16 = fp16_in[14:10];
    wire [9:0] mant16 = fp16_in[9:0];

    // Detect special 16-bit values
    wire is_nan16 = (exp16 == 5'h1F) && (mant16 != 0);
    wire is_inf16 = (exp16 == 5'h1F) && (mant16 == 0);
    wire is_zero16 = (exp16 == 0) && (mant16 == 0);
    wire is_denorm16 = (exp16 == 0) && (mant16 != 0);

    integer shift_amount;
    wire [9:0] temp_mant = mant16;
    reg [7:0] exp32;
    reg [22:0] mant32;
    always @(*) begin
        if (is_nan16) begin
            // Propagate NaN, making it a quiet NaN in 32-bit format
            fp32_out = {sign, 8'hFF, {1'b1, mant16, 12'b0}};
        end else if (is_inf16) begin
            fp32_out = {sign, 8'hFF, 23'b0};
        end else if (is_zero16) begin
            fp32_out = {sign, 31'b0};
        end else if (is_denorm16) begin
            // Normalize the denormalized 16-bit number
            
            // Find leading '1' to determine shift
            shift_amount = 0;
            for(integer i=9; i>=0; i=i-1) begin
                if(temp_mant[i]) shift_amount = 9 - i;
            end
            
            exp32 = 127 - 15 - shift_amount;
            mant32 = (temp_mant << (shift_amount + 1))[9:0] << 13;
            fp32_out = {sign, exp32, mant32};
        end else begin
            // Normal conversion
            exp32 = exp16 - 15 + 127;
            mant32 = {mant16, 13'b0}; // Pad mantissa with zeros
            fp32_out = {sign, exp32, mant32};
        end
    end

endmodule
