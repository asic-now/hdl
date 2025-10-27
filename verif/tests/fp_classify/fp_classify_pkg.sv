// verif/tests/fp_classify/fp_classify_pkg.sv
// Package for the parameterized fp_classify UVM testbench.

package fp_classify_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    import fp_lib_pkg::*;

    // ATTENTION: DO NOT INCLUDE ANY files with `module` or `interface` here. Include them in filelist.txt.

    // Include DUT-specific components
    `include "fp_classify_transaction.sv"
    `include "fp_classify_driver.sv"
    `include "fp_classify_monitor.sv"
    `include "fp_classify_agent.sv"
    `include "fp_classify_model.sv"
    `include "fp_classify_env.sv"

    // Sequences & Tests
    `include "fp_classify_base_test.sv"
    `include "fp_classify_random_sequence.sv"
    `include "fp_classify_random_test.sv"
    `include "fp_classify_special_cases_sequence.sv"
    `include "fp_classify_special_cases_test.sv"
    `include "fp_classify_combined_sequence.sv"
    `include "fp_classify_combined_test.sv"

endpackage
