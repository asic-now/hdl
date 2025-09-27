// verif/lib/fp_lib_pkg.sv
// This package contains reusable floating-point verification components.

package fp_lib_pkg;
    import uvm_pkg::*;

    // Include reusable library components
    `include "fp_utils.sv"
    `include "common_inc.svh"
    `include "base_scoreboard.sv"
    `include "base_test.sv"
    `include "base_transaction.sv"
    `include "fp_transaction.sv"
    `include "fp_driver_base.sv"
    `include "fp_monitor_base.sv"
    `include "fp_model_base.sv"
    `include "fp16_transaction2.sv"
    `include "fp16_sequence2_random.sv"
endpackage
