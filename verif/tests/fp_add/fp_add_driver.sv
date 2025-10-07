// verif/tests/fp_add/fp_add_driver.sv
// Parameterized UVM driver for the fp_add DUT.

`include "uvm_macros.svh"
import uvm_pkg::*;

class fp_add_driver #(
    parameter int WIDTH = 16
) extends fp_driver_base #(fp_transaction2 #(WIDTH), virtual fp_add_if #(WIDTH));

    `uvm_component_param_utils(fp_add_driver #(WIDTH))

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    // Implementation of the DUT-specific drive task
    virtual task drive_transfer(fp_transaction2 #(WIDTH) trans);
        vif.a <= trans.inputs[0];
        vif.b <= trans.inputs[1];
        `uvm_info("DRIVER", $sformatf("Drove transaction: a=0x%h, b=0x%h", trans.inputs[0], trans.inputs[1]), UVM_HIGH)
    endtask

endclass
