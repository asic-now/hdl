// verif/tests/fp_add/fp_add_pkg.sv
// Main package for the parameterized fp_add UVM testbench.

package fp_add_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // Reusable library components
    import fp_lib_pkg::*; // Import the reusable library

    // ATTENTION: DO NOT INCLUDE ANY files with `module` or `interface` here. Include them in filelist.txt.

    // Include DUT-specific components
    `include "fp_add_driver.sv"
    `include "fp_add_monitor.sv"
    `include "fp_add_agent.sv"
    `include "fp_add_model.sv"
    `include "fp_add_env.sv"

    // Sequences & Tests
    `include "fp_add_base_test.sv"
    `include "fp_add_random_test.sv"
    `include "fp_add_special_cases_sequence.sv"
    `include "fp_add_special_cases_test.sv"
    `include "fp_add_combined_sequence.sv"
    `include "fp_add_combined_test.sv"
endpackage
