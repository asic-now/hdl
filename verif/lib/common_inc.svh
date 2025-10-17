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


// Macro replacing `uvm_component_param_utils() for parameterized test components.
// See https://dvcon-proceedings.org/wp-content/uploads/parameters-uvm-coverage-emulation-take-two-and-call-me-in-the-morning.pdf
// Usage:
// 1. Use '`my_uvm_component_param_utils(<component> #(<params>), "<component_name>")' in place of '`uvm_component_param_utils()'.
// 2. Add 'typedef <component> #(<params>) <component>_t;' to the testbench top (it declares types so the UVM registration happens).
// 3. Use +UVM_TESTNAME="<component_name>" in command line to select the test.
`define my_uvm_component_param_utils(T, S) \
     typedef uvm_component_registry #(T, S) type_id; \
     static function type_id get_type(); \
         return type_id::get(); \
     endfunction \
     virtual function uvm_object_wrapper get_object_type(); \
         return type_id::get(); \
     endfunction
    // const static string type_name = $sformatf("fp_add_combined_test  #(%1d)", WIDTH);
    // virtual function string get_type_name();
    //     return type_name;
    // endfunction

`endif // COMMON_INC_SVH