// fp16_add_pkg.sv
// This package imports the UVM library and includes all the component
// files for the fp16_add testbench, making them available for compilation.

package fp16_add_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // Include reusable library components
    `include "fp_transaction_base.sv"
    `include "fp_model_base.sv"
    `include "fp_scoreboard.sv"

    // Include DUT-specific components
    // `include "fp16_add_if.sv" // TODO: (when needed) Does not work in the package.
    `include "fp16_add_transaction.sv"
    `include "fp16_add_sequence.sv"
    `include "fp16_add_driver.sv"
    `include "fp16_add_monitor.sv"
    `include "fp16_add_agent.sv"
    `include "fp16_add_model.sv"
    `include "fp16_add_env.sv"
    `include "fp16_add_base_test.sv"
    `include "fp16_add_random_test.sv"
endpackage
