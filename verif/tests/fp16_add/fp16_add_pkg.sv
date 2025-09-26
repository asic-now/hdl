// verif/tests/fp16_add/fp16_add_pkg.sv
// This package imports the UVM library and includes all the component
// files for the fp16_add testbench, making them available for compilation.

package fp16_add_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // Reusable library components
    import fp_lib_pkg::*; // Import the reusable library

    // ATTENTION: DO NOT INCLUDE ANY files with `module` or `interface` here. Include them in filelist.txt.

    // Include DUT-specific components
    `include "fp16_add_driver.sv"
    `include "fp16_add_monitor.sv"
    `include "fp16_add_agent.sv"
    `include "fp16_add_model.sv"
    `include "fp16_add_env.sv"

    // Sequences & Tests
    `include "fp16_add_base_test.sv"
    `include "fp16_add_random_sequence.sv"
    `include "fp16_add_random_test.sv"
    `include "fp16_add_special_cases_sequence.sv"
    `include "fp16_add_special_cases_test.sv"
    `include "fp16_add_combined_sequence.sv"
    `include "fp16_add_combined_test.sv"
endpackage
