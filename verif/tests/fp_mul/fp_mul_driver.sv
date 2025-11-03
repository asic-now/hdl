// verif/tests/fp_mul/fp_mul_driver.sv
// Parameterized UVM driver for the fp_mul DUT.

`include "uvm_macros.svh"
import uvm_pkg::*;

`include "grs_round.vh"  // \`RNE, etc.

class fp_mul_driver #(
    parameter int WIDTH = 16
) extends fp_driver_base #(fp_transaction2 #(WIDTH), virtual fp_mul_if #(WIDTH));

    `uvm_component_param_utils(fp_mul_driver #(WIDTH))

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    // Implementation of the DUT-specific drive task
    virtual task drive_transfer(fp_transaction2 #(WIDTH) trans);
        string rm_str;
        case (trans.rm)
            `RNE: rm_str = "RNE";
            `RTZ: rm_str = "RTZ";
            `RPI: rm_str = "RPI";
            `RNI: rm_str = "RNI";
            `RNA: rm_str = "RNA";
            default: rm_str = $sformatf("UNK(%0d)", trans.rm);
        endcase
        vif.a <= trans.inputs[0];
        vif.b <= trans.inputs[1];
        vif.rm <= trans.rm;
        `uvm_info("DRIVER", $sformatf("Drove transaction: a=0x%h, b=0x%h, rm=%s", trans.inputs[0], trans.inputs[1], rm_str), UVM_HIGH)
    endtask

endclass
