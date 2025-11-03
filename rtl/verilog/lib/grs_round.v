// rtl/verilog/lib/grs_round.v
// A pure combinational logic module that implements the GRS rounding decision.
//   It supports dynamic selection of all five common rounding modes, including
//   the four specified by IEEE 754.
//
// Parameters:
//   INPUT_WIDTH  - The bit width of the unrounded input value_in.
//   OUTPUT_WIDTH - The bit width of the final rounded value_out.
//

`include "grs_round.vh"  // \`RNE, etc.

module grs_round #(
    parameter INPUT_WIDTH  = 28,
    parameter OUTPUT_WIDTH = 24
) (
    input  wire [INPUT_WIDTH-1:0]  value_in,
    input  wire                    sign_in,
    input  wire [2:0]              mode,
    output wire                    increment
);

    // --- 1. Calculate Truncation and GRS Bits from Input Value ---
    localparam signed SHIFT_AMOUNT = INPUT_WIDTH - OUTPUT_WIDTH;

    wire lsb = (SHIFT_AMOUNT >= 0) ? value_in[SHIFT_AMOUNT - 0] : 1'b0;

    // Guard bit: The most significant bit of the truncated portion.
    wire g   = (SHIFT_AMOUNT >= 1) ? value_in[SHIFT_AMOUNT - 1] : 1'b0;

    // Round bit: The bit immediately to the right of the Guard bit.
    wire r   = (SHIFT_AMOUNT >= 2) ? value_in[SHIFT_AMOUNT - 2] : 1'b0;

    // Sticky bit: The logical OR of all bits to the right of the Round bit.
    wire s   = (SHIFT_AMOUNT >= 3) ? |(value_in[SHIFT_AMOUNT - 3 : 0]) : 1'b0;
    
    // Inexact bit: True if any truncated bit is non-zero. Simplifies logic.
    wire inexact = (g | r | s);

    // --- 2. Combinatorial Rounding Decision Logic ---
    reg do_increment;

    always @(*) begin
        do_increment = 1'b0; // Default to no increment
        case (mode)
            // RNE: Round up if > 0.5 LSB, or exactly 0.5 LSB and LSB is 1 (to make it even).
            // This is compactly expressed as G & (L | R | S).
            `RNE: do_increment = g & (r | s | lsb);

            // RTZ: Always truncate. Never increment.
            `RTZ: do_increment = 1'b0;

            // RPI: If positive and inexact, round up (towards +inf). If negative, truncate.
            `RPI: do_increment = !sign_in & inexact;

            // RNI: If negative and inexact, round up (towards -inf). If positive, truncate.
            `RNI: do_increment = sign_in & inexact;

            // RNA: Round up if >= 0.5 LSB. This is true if the Guard bit is 1.
            `RNA: do_increment = g;

            // Default case also truncates for safety
            default: do_increment = 1'b0;
        endcase
    end

    assign increment = do_increment;

endmodule
