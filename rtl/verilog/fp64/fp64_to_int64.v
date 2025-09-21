// rtl/verilog/fp64/fp64_to_int64.v
//
// Verilog RTL to convert a 64-bit float to a 64-bit signed integer.
//
// Features:
// - Combinational logic.
// - Truncates fractional part (round towards zero).
// - Handles NaN, Infinity (saturates), and Zero.
// - Saturates on overflow.

module fp64_to_int64 (
    input  [63:0] fp_in,
    output reg [63:0] int_out
);

    // Unpack input
    wire sign = fp_in[63];
    wire [10:0] exp = fp_in[62:52];
    wire [51:0] mant = fp_in[51:0];

    // Detect special values
    wire is_nan = (exp == 11'h7FF) && (mant != 0);
    wire is_inf = (exp == 11'h7FF) && (mant == 0);
    wire is_zero = (exp == 0) && (mant == 0);

    // Constants for saturation
    localparam INT64_MAX = 64'h7FFFFFFFFFFFFFFF;
    localparam INT64_MIN = 64'h8000000000000000;

    reg  signed [11:0] true_exp;
    reg  [52:0] full_mant;
    reg  [115:0] shifted_val; // 53 mant bits + 63 max shift
    always @(*) begin
        if (is_nan) begin
            int_out = 64'd0; // Return 0 for NaN
        end else if (is_inf) begin
            int_out = sign ? INT64_MIN : INT64_MAX;
        end else if (is_zero) begin
            int_out = 64'd0;
        end else begin
            // Normal conversion
            true_exp = exp - 1023;
            full_mant = {1'b1, mant}; // Add implicit 1

            if (true_exp < 0) begin // Value is < 1.0
                int_out = 64'd0;
            end else if (true_exp > 63) begin // Overflow
                int_out = sign ? INT64_MIN : INT64_MAX;
            end else begin
                // Shift mantissa to align integer part
                shifted_val = full_mant << true_exp;

                // Check for overflow after shift
                if (shifted_val > INT64_MAX) begin
                    int_out = sign ? INT64_MIN : INT64_MAX;
                end else begin
                    int_out = sign ? -shifted_val[63:0] : shifted_val[63:0];
                end
            end
        end
    end

endmodule
