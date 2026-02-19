// verif/tests/systolic/systolic_pkg.sv
// Package for the parameterized systolic UVM testbench.

package systolic_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    `include "systolic_item.sv"
    `include "systolic_driver.sv"
    `include "systolic_monitor.sv"
    `include "systolic_agent.sv"
    `include "systolic_scoreboard.sv"
    `include "systolic_env.sv"
    `include "systolic_sequence.sv"
    `include "systolic_random_test.sv"

endpackage
