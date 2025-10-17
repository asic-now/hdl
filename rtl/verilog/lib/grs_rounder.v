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

`include "grs_round.vh" // Defines Rounding Modes

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

    // --- 1. Instantiate Decision Logic Module ---
    // The grs_round module handles GRS calculation
    wire increment;
    grs_round #(
        .INPUT_WIDTH(INPUT_WIDTH),
        .OUTPUT_WIDTH(OUTPUT_WIDTH)
    ) u_grs_round (
        .value_in(value_in),
        .sign_in(sign_in),
        .mode(mode),
        .increment(increment)
    );

    // --- 2. Calculate Base Mantissa for Addition ---
    localparam SHIFT_AMOUNT = INPUT_WIDTH - OUTPUT_WIDTH;
    wire [OUTPUT_WIDTH-1:0] base_mantissa;
    assign base_mantissa = value_in[INPUT_WIDTH-1 : SHIFT_AMOUNT];

    // --- 3. Final Output Calculation with Overflow Detection ---
    // Use a vector one bit wider than the output to capture the carry-out.
    wire [OUTPUT_WIDTH:0] sum;
    assign sum = {1'b0, base_mantissa} + increment;

    // Assign the sum to the outputs. The MSB is the overflow.
    assign overflow_out = sum[OUTPUT_WIDTH];
    assign value_out    = sum[OUTPUT_WIDTH-1:0];

endmodule
