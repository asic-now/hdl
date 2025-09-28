// rtl/verilog/lib/common_inc.vh
//
// Common macros for RTL modules.

`ifndef COMMON_INC_VH
`define COMMON_INC_VH

// Macro to add verification support for pipeline latency.
// It defines a localparam for the latency and a synthesizable
// accessor function for the testbench to read it.
//
// Usage: `VERIF_DECLARE_PIPELINE(<latency_value>)
//
`define VERIF_DECLARE_PIPELINE(LATENCY) \
    localparam integer PIPELINE_LATENCY = LATENCY;

`endif // COMMON_INC_VH
