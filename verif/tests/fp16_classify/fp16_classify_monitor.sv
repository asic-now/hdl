// fp16_classify_monitor.sv
// Monitors the DUT interface and reports transactions.

`include "uvm_macros.svh"
import uvm_pkg::*;

// class fp16_classify_monitor extends uvm_monitor;
class fp16_classify_monitor extends fp_monitor_base #(fp16_classify_transaction, virtual fp16_classify_if);
    `uvm_component_utils(fp16_classify_monitor)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    // Implementation of the DUT-specific sample task
    // It only creates and returns a transaction if inputs are valid.
    virtual task sample_inputs(output fp16_classify_transaction trans);
        if (! (^vif.monitor_cb.in === 1'bx)) begin
            trans = fp16_classify_transaction::type_id::create("trans_input");
            trans.inputs[0] = vif.monitor_cb.in;
        end else begin
            trans = null;
        end
    endtask

    // Implementation of the DUT-specific output sampling task
    virtual task sample_output(fp16_classify_transaction trans);
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
