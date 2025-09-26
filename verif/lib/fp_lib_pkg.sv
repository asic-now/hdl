// verif/lib/fp_lib_pkg.sv
//
// This package contains all the generic, reusable base classes and utilities
// for the floating-point verification environment. Test-specific packages
// should 'import' this package to use the framework.

package fp_lib_pkg;
    import uvm_pkg::*;

    // Include reusable library components
    import fp_utils_pkg::*;
    // `include "fp_utils.sv"
    `include "common_inc.svh"
    `include "base_scoreboard.sv"
    `include "base_test.sv"
    `include "base_transaction.sv"
    `include "fp_transaction.sv"
    `include "fp_driver_base.sv"
    `include "fp_monitor_base.sv"
    `include "fp_model_base.sv"
    `include "fp16_transaction2.sv"

endpackage
