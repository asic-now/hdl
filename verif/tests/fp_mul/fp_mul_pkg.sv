// verif/tests/fp_mul/fp_mul_pkg.sv
// Package for the parameterized fp_mul UVM testbench.

package fp_mul_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    import fp_lib_pkg::*;

    // ATTENTION: DO NOT INCLUDE ANY files with `module` or `interface` here. Include them in filelist.txt.

    // Include DUT-specific components
    `include "fp_mul_driver.sv"
    `include "fp_mul_monitor.sv"
    `include "fp_mul_agent.sv"
    `include "fp_mul_model.sv"
    `include "fp_mul_env.sv"

    // Sequences & Tests
    `include "fp_mul_base_test.sv"
    `include "fp_mul_random_test.sv"
    `include "fp_mul_special_cases_sequence.sv"
    `include "fp_mul_special_cases_test.sv"
    `include "fp_mul_combined_sequence.sv"
    `include "fp_mul_combined_test.sv"

endpackage
