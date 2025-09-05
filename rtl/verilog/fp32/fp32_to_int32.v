// fp32_to_int32.v
//
// Verilog RTL to convert a 32-bit float to a 32-bit signed integer.
//
// Features:
// - Combinational logic.
// - Truncates fractional part (round towards zero).
// - Handles NaN, Infinity (saturates), and Zero.
// - Saturates on overflow.

module fp32_to_int32 (
    input  [31:0] fp_in,
    output reg [31:0] int_out
);

    // Unpack input
    wire sign = fp_in[31];
    wire [7:0] exp = fp_in[30:23];
    wire [22:0] mant = fp_in[22:0];

    // Detect special values
    wire is_nan = (exp == 8'hFF) && (mant != 0);
    wire is_inf = (exp == 8'hFF) && (mant == 0);
    wire is_zero = (exp == 0) && (mant == 0);

    // Constants for saturation
    localparam INT32_MAX = 32'h7FFFFFFF;
    localparam INT32_MIN = 32'h80000000;

    always @(*) begin
        if (is_nan) begin
            int_out = 32'h00000000; // Return 0 for NaN
        end else if (is_inf) begin
            int_out = sign ? INT32_MIN : INT32_MAX;
        end else if (is_zero) begin
            int_out = 32'h00000000;
        end else begin
            // Normal conversion
            reg signed [8:0] true_exp = exp - 127;
            reg [23:0] full_mant = {1'b1, mant}; // Add implicit 1
            reg [54:0] shifted_val; // 24 mant bits + 31 max shift

            if (true_exp < 0) begin // Value is < 1.0
                int_out = 32'h00000000;
            end else if (true_exp > 31) begin // Overflow
                int_out = sign ? INT32_MIN : INT32_MAX;
            end else begin
                // Shift mantissa to align integer part
                shifted_val = full_mant << true_exp;

                // Check for overflow after shift
                if (shifted_val > INT32_MAX) begin
                    int_out = sign ? INT32_MIN : INT32_MAX;
                end else begin
                    int_out = sign ? -shifted_val[31:0] : shifted_val[31:0];
                end
            end
        end
    end

endmodule
