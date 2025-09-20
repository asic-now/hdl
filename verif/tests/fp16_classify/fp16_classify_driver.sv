// fp16_classify_driver.sv
// Drives transactions to the fp16_classify DUT.

`include "uvm_macros.svh"
import uvm_pkg::*;

class fp16_classify_driver extends fp_driver_base #(fp16_classify_transaction, virtual fp16_classify_if);
    `uvm_component_utils(fp16_classify_driver)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    // Implementation of the DUT-specific drive task
    virtual task drive_transfer(fp16_classify_transaction trans);
        vif.in <= trans.inputs[0];
        `uvm_info("DRIVER", $sformatf("Drove transaction: in=0x%h", trans.inputs[0]), UVM_HIGH)
    endtask

endclass
