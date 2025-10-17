// rtl/verilog/lib/grs_round.vh
// This header file provides a single source of truth for the rounding mode
// encodings used throughout the floating-point unit.

`ifndef _GRS_ROUND_VH
`define _GRS_ROUND_VH

`define RNE 3'b000 // Round to Nearest, Ties to Even (Default IEEE mode)
`define RTZ 3'b001 // Round Towards Zero / Truncation
`define RPI 3'b010 // Round Towards Positive Infinity
`define RNI 3'b011 // Round Towards Negative Infinity
`define RNA 3'b100 // Round to Nearest, Ties Away from Zero

`endif // _GRS_ROUND_VH
