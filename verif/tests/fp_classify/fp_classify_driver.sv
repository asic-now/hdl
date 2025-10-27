// verif/tests/fp_classify/fp_classify_driver.sv
// Parameterized UVM driver for the fp_classify DUT.

`include "uvm_macros.svh"
import uvm_pkg::*;

class fp_classify_driver #(
    parameter int WIDTH = 16
) extends fp_driver_base #(fp_classify_transaction #(WIDTH), virtual fp_classify_if #(WIDTH));

    `uvm_component_param_utils(fp_classify_driver #(WIDTH))

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    // Implementation of the DUT-specific drive task
    virtual task drive_transfer(fp_classify_transaction #(WIDTH) trans);
        vif.in <= trans.inputs[0];
        `uvm_info("DRIVER", $sformatf("Drove transaction: in=0x%h", trans.inputs[0]), UVM_HIGH)
    endtask

endclass
