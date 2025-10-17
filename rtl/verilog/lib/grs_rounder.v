// rtl/verilog/lib/grs_rounder.v
// A fully combinatorial, parameterized GRS (Guard, Round, Sticky) rounder.
//   It supports dynamic selection of all five common rounding modes, including
//   the four specified by IEEE 754.
//
// Parameters:
//   INPUT_WIDTH  - The bit width of the unrounded input value_in.
//   OUTPUT_WIDTH - The bit width of the final rounded value_out.
//
// Rounding Modes (controlled by 'mode' input):
//   - 3'b000: RNE (Round to Nearest, Ties to Even) - Default IEEE mode.
//   - 3'b001: RTZ (Round Towards Zero) - Truncation.
//   - 3'b010: RPI (Round Towards Positive Infinity)
//   - 3'b011: RNI (Round Towards Negative Infinity)
//   - 3'b100: RNA (Round to Nearest, Ties Away from Zero)
//

module grs_rounder #(
    parameter INPUT_WIDTH  = 28,
    parameter OUTPUT_WIDTH = 24
) (
    input  wire [INPUT_WIDTH-1:0]  value_in,
    input  wire                    sign_in,
    input  wire [2:0]              mode,
    output wire [OUTPUT_WIDTH-1:0] value_out,
    output wire                    overflow_out
);

    // --- 1. Define Rounding Mode Constants ---
    localparam RNE = 3'b000; // Round to Nearest, Ties to Even // IEEE 754 default
    localparam RTZ = 3'b001; // Round Towards Zero
    localparam RPI = 3'b010; // Round Towards Positive Infinity
    localparam RNI = 3'b011; // Round Towards Negative Infinity
    localparam RNA = 3'b100; // Round to Nearest, Ties Away from Zero

    // --- 2. Calculate Truncation and GRS Bits ---
    localparam SHIFT_AMOUNT = INPUT_WIDTH - OUTPUT_WIDTH;

    wire [OUTPUT_WIDTH-1:0] base_mantissa;
    assign base_mantissa = value_in[INPUT_WIDTH-1 : SHIFT_AMOUNT];

    wire lsb;
    assign lsb = base_mantissa[0];

    wire [SHIFT_AMOUNT-1:0] truncated_bits;
    assign truncated_bits = value_in[SHIFT_AMOUNT-1 : 0];

    // Guard bit: The most significant bit of the truncated portion.
    wire g;
    assign g = (SHIFT_AMOUNT > 0) ? truncated_bits[SHIFT_AMOUNT - 1] : 1'b0;

    // Round bit: The bit immediately to the right of the Guard bit.
    wire r;
    assign r = (SHIFT_AMOUNT > 1) ? truncated_bits[SHIFT_AMOUNT - 2] : 1'b0;

    // Sticky bit: The logical OR of all bits to the right of the Round bit.
    wire s;
    assign s = (SHIFT_AMOUNT > 2) ? |(truncated_bits[SHIFT_AMOUNT - 3 : 0]) : 1'b0;
    
    // Inexact bit: True if any truncated bit is non-zero. Simplifies logic.
    wire inexact;
    assign inexact = (g | r | s);

    // --- 3. Combinatorial Rounding Logic ---
    reg increment;

    always @(*) begin
        increment = 1'b0;
        case (mode)
            // RNE: Round up if > 0.5 LSB, or exactly 0.5 LSB and LSB is 1 (to make it even).
            // This is compactly expressed as G & (L | R | S).
            RNE: increment = g & (lsb | r | s);

            // RTZ: Always truncate. Never increment.
            RTZ: increment = 1'b0;

            // RPI: If positive and inexact, round up (towards +inf). If negative, truncate.
            RPI: increment = !sign_in & inexact;

            // RNI: If negative and inexact, round up (towards -inf). If positive, truncate.
            RNI: increment = sign_in & inexact;

            // RNA: Round up if >= 0.5 LSB. This is true if the Guard bit is 1.
            RNA: increment = g;

            // Default case also truncates for safety
            default: increment = 1'b0;
        endcase
    end

    // --- 4. Final Output Calculation with Overflow Detection ---
    // Use a wire one bit wider than the output to capture the carry-out.
    wire [OUTPUT_WIDTH:0] sum;
    assign sum = {1'b0, base_mantissa} + increment;

    // Assign the sum to the outputs. The MSB is the overflow.
    assign overflow_out = sum[OUTPUT_WIDTH];
    assign value_out    = sum[OUTPUT_WIDTH-1:0];

endmodule
