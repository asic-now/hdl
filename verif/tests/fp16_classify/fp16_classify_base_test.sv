// verif/tests/fp16_classify/fp16_classify_base_test.sv
// Base test class for the fp16_classify verification environment.

`include "uvm_macros.svh"

// Inherit from the generic base_test, parameterizing it with our specific environment.
// This removes all boilerplate code for handling latency and printing topology.
class fp16_classify_base_test extends base_test #(fp16_classify_env);
    `uvm_component_utils(fp16_classify_base_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

endclass
