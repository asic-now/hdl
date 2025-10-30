// verif/tests/fp_mul/fp_mul_monitor.sv
// Parameterized UVM monitor for the fp_mul DUT.

`include "uvm_macros.svh"
import uvm_pkg::*;

class fp_mul_monitor #(
    parameter int WIDTH = 16
) extends fp_monitor_base #(fp_transaction2 #(WIDTH), virtual fp_mul_if #(WIDTH));

    `uvm_component_param_utils(fp_mul_monitor #(WIDTH))

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    // Implementation of the DUT-specific sample task
    // It only creates and returns a transaction if inputs are valid.
    virtual task sample_inputs(output fp_transaction2 #(WIDTH) trans);
        if (! (^vif.monitor_cb.a === 1'bx) && ! (^vif.monitor_cb.b === 1'bx)) begin
            trans = fp_transaction2 #(WIDTH)::type_id::create("trans_input");
            trans.inputs[0] = vif.monitor_cb.a;
            trans.inputs[1] = vif.monitor_cb.b;
        end else begin
            trans = null;
        end
    endtask

    // Implementation of the DUT-specific output sampling task
    virtual task sample_output(fp_transaction2 #(WIDTH) trans);
        trans.result = vif.monitor_cb.result;
    endtask

endclass
