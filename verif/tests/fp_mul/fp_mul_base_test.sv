// verif/tests/fp_mul/fp_mul_base_test.sv
// Base test class for the fp_mul UVM environment.

`include "uvm_macros.svh"
import uvm_pkg::*;

class fp_mul_base_test #(
    parameter int WIDTH = 16
) extends base_test #(fp_mul_env #(WIDTH));

    `uvm_component_param_utils(fp_mul_base_test #(WIDTH))

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

endclass
