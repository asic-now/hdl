// rtl/verilog/fp16/fp16_to_int16.v
//
// Verilog RTL to convert a 16-bit float to a 16-bit signed integer.
//
// Features:
// - Combinational logic.
// - Truncates fractional part (round towards zero).
// - Handles NaN, Infinity (saturates), and Zero.
// - Saturates on overflow.

module fp16_to_int16 (
    input  [15:0] fp_in,
    output reg [15:0] int_out
);

    // Unpack input
    wire       sign = fp_in[15];
    wire [4:0] exp  = fp_in[14:10];
    wire [9:0] mant = fp_in[9:0];

    // Detect special values
    wire is_nan = (exp == 5'h1F) && (mant != 0);
    wire is_inf = (exp == 5'h1F) && (mant == 0);
    wire is_zero = (exp == 0) && (mant == 0);

    // Constants for saturation
    localparam INT16_MAX = 16'h7FFF;
    localparam INT16_MIN = 16'h8000;

    reg signed [ 5:0] true_exp;
    reg        [10:0] full_mant;
    reg        [26:0] shifted_val; // 11 mant bits + 15 max shift
    always @(*) begin
        if (is_nan) begin
            int_out = 16'h0000; // Return 0 for NaN
        end else if (is_inf) begin
            int_out = sign ? INT16_MIN : INT16_MAX;
        end else if (is_zero) begin
            int_out = 16'h0000;
        end else begin
            // Normal conversion
            true_exp = exp - 15;
            full_mant = {1'b1, mant}; // Add implicit 1

            if (true_exp < 0) begin // Value is < 1.0
                int_out = 16'h0000;
            end else if (true_exp > 15) begin // Overflow
                int_out = sign ? INT16_MIN : INT16_MAX;
            end else begin
                // Shift mantissa to align integer part
                shifted_val = full_mant << true_exp;

                // Check for overflow after shift (e.g., for 32768.5)
                if (shifted_val > INT16_MAX) begin
                    int_out = sign ? INT16_MIN : INT16_MAX;
                end else begin
                    int_out = sign ? -shifted_val[15:0] : shifted_val[15:0];
                end
            end
        end
    end

endmodule
