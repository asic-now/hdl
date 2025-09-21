// verif/tests/fp16_classify/fp16_classify_pkg.sv
// This package imports the UVM library and includes all the component
// files for the fp16_classify testbench, making them available for compilation.

package fp16_classify_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // Reusable library components
    import fp_lib_pkg::*; // Import the reusable library

    // Include DUT-specific components
    // `include "fp16_classify_if.sv" // TODO: (when needed) Does not work in the package.
    `include "fp16_classify_transaction.sv"
    `include "fp16_classify_driver.sv"
    `include "fp16_classify_monitor.sv"
    `include "fp16_classify_agent.sv"
    `include "fp16_classify_model.sv"
    `include "fp16_classify_env.sv"

    // Sequences & Tests
    `include "fp16_classify_base_test.sv"
    `include "fp16_classify_random_sequence.sv"
    `include "fp16_classify_random_test.sv"
    `include "fp16_classify_special_cases_sequence.sv"
    `include "fp16_classify_special_cases_test.sv"
    `include "fp16_classify_combined_sequence.sv"
    `include "fp16_classify_combined_test.sv"
endpackage
