// verif/tests/fp_mul/fp_mul_driver.sv
// Parameterized UVM driver for the fp_mul DUT.

`include "uvm_macros.svh"
import uvm_pkg::*;

class fp_mul_driver #(
    parameter int WIDTH = 16
) extends fp_driver_base #(fp_transaction2 #(WIDTH), virtual fp_mul_if #(WIDTH));

    `uvm_component_param_utils(fp_mul_driver #(WIDTH))

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    // Implementation of the DUT-specific drive task
    virtual task drive_transfer(fp_transaction2 #(WIDTH) trans);
        string rounding_mode_str;
        case (trans.rounding_mode)
            `RNE: rounding_mode_str = "RNE";
            `RTZ: rounding_mode_str = "RTZ";
            `RPI: rounding_mode_str = "RPI";
            `RNI: rounding_mode_str = "RNI";
            `RNA: rounding_mode_str = "RNA";
            default: rounding_mode_str = $sformatf("UNK(%0d)", trans.rounding_mode);
        endcase
        vif.a <= trans.inputs[0];
        vif.b <= trans.inputs[1];
        vif.rounding_mode <= trans.rounding_mode;
        `uvm_info("DRIVER", $sformatf("Drove transaction: a=0x%h, b=0x%h, rm=%s", trans.inputs[0], trans.inputs[1], rounding_mode_str), UVM_HIGH)
    endtask

endclass
