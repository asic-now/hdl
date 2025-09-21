// verif/tests/fp16_add/fp16_add_driver.sv
// Implements the pure virtual 'drive_transfer' task for the 2-input adder.

`include "uvm_macros.svh"
import uvm_pkg::*;

class fp16_add_driver extends fp_driver_base #(fp16_add_transaction, virtual fp16_add_if);
    `uvm_component_utils(fp16_add_driver)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    // Implementation of the DUT-specific drive task
    virtual task drive_transfer(fp16_add_transaction trans);
        vif.a <= trans.inputs[0];
        vif.b <= trans.inputs[1];
        `uvm_info("DRIVER", $sformatf("Drove transaction: a=0x%h, b=0x%h", trans.inputs[0], trans.inputs[1]), UVM_HIGH)
    endtask

endclass
