// verif/tests/fp_classify/fp_classify_monitor.sv
// Parameterized UVM monitor for the fp_classify DUT.

`include "uvm_macros.svh"
import uvm_pkg::*;

class fp_classify_monitor #(
    parameter int WIDTH = 16
) extends fp_monitor_base #(fp_classify_transaction #(WIDTH), virtual fp_classify_if #(WIDTH));

    `uvm_component_param_utils(fp_classify_monitor #(WIDTH))

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    // Implementation of the DUT-specific sample task
    // It only creates and returns a transaction if inputs are valid.
    virtual task sample_inputs(output fp_classify_transaction #(WIDTH) trans);
        if (! (^vif.monitor_cb.in === 1'bx)) begin
            trans = fp_classify_transaction #(WIDTH)::type_id::create("trans_input");
            trans.inputs[0] = vif.monitor_cb.in;
        end else begin
            trans = null;
        end
    endtask

    // Implementation of the DUT-specific output sampling task
    virtual task sample_output(fp_classify_transaction #(WIDTH) trans);
        trans.result.is_snan         = vif.monitor_cb.is_snan         ;
        trans.result.is_qnan         = vif.monitor_cb.is_qnan         ;
        trans.result.is_neg_inf      = vif.monitor_cb.is_neg_inf      ;
        trans.result.is_neg_normal   = vif.monitor_cb.is_neg_normal   ;
        trans.result.is_neg_denormal = vif.monitor_cb.is_neg_denormal ;
        trans.result.is_neg_zero     = vif.monitor_cb.is_neg_zero     ;
        trans.result.is_pos_zero     = vif.monitor_cb.is_pos_zero     ;
        trans.result.is_pos_denormal = vif.monitor_cb.is_pos_denormal ;
        trans.result.is_pos_normal   = vif.monitor_cb.is_pos_normal   ;
        trans.result.is_pos_inf      = vif.monitor_cb.is_pos_inf      ;
        // `uvm_info("MONITOR", $sformatf("Collected transaction: in=0x%h, result=0x%h", trans_out.in, trans_out.result), UVM_HIGH)
    endtask

endclass
