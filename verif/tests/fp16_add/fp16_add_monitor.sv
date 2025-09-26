// verif/tests/fp16_add/fp16_add_monitor.sv
// Implements the pure virtual 'sample_inputs' task for the 2-input adder.

`include "uvm_macros.svh"
import uvm_pkg::*;

class fp16_add_monitor extends fp_monitor_base #(fp16_transaction2, virtual fp16_add_if);
    `uvm_component_utils(fp16_add_monitor)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    // Implementation of the DUT-specific sample task
    // It only creates and returns a transaction if inputs are valid.
    virtual task sample_inputs(output fp16_transaction2 trans);
        if (! (^vif.monitor_cb.a === 1'bx) && ! (^vif.monitor_cb.b === 1'bx)) begin
            trans = fp16_transaction2::type_id::create("trans_input");
            trans.inputs[0] = vif.monitor_cb.a;
            trans.inputs[1] = vif.monitor_cb.b;
        end else begin
            trans = null;
        end
    endtask

    // Implementation of the DUT-specific output sampling task
    virtual task sample_output(fp16_transaction2 trans);
        trans.result = vif.monitor_cb.result;
    endtask

endclass
