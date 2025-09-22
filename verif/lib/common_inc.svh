// verif/lib/common_inc.svh
//
// Common macros for SystemVerilog modules.

`ifndef COMMON_INC_SVH
`define COMMON_INC_SVH

// Macro to add verification support for pipeline latency.
// It defines int variable pipeline_latency and reads it from DUT.PIPELINE_LATENCY.
//
// Usage: `VERIF_GET_DUT_PIPELINE(<DUT_instance>)
//    pipeline_latency can be used in the testbench to check DUT pipeline latency.
//
`define VERIF_GET_DUT_PIPELINE(DUT) \
    int pipeline_latency; \
    initial begin \
        // Get the latency from DUT (Should be declared with `VERIF_DECLARE_PIPELINE()) \
        pipeline_latency = int'(DUT.PIPELINE_LATENCY); \
        `uvm_info("TB_TOP", $sformatf("Read pipeline latency from DUT: %0d", pipeline_latency), UVM_LOW) \
        uvm_config_db#(int)::set(null, "*", "pipeline_latency", pipeline_latency); \
    end

`endif // COMMON_INC_SVH