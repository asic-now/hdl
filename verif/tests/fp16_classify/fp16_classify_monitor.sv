// fp16_classify_monitor.sv
// Monitors the DUT interface and reports transactions.

`include "uvm_macros.svh"
import uvm_pkg::*;

class fp16_classify_monitor extends uvm_monitor;
    `uvm_component_utils(fp16_classify_monitor)

    virtual fp16_classify_if vif;
    uvm_analysis_port #(fp16_classify_transaction) ap;

    // A queue to store input transactions and align them with the pipelined output
    fp16_classify_transaction input_queue[$];
    
    local static const int PIPELINE_LATENCY = 0;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(virtual fp16_classify_if)::get(this, "", "dut_vif", vif))
            `uvm_fatal("NOVIF", "Could not get virtual interface handle")
    endfunction

    virtual task run_phase(uvm_phase phase);
        // Fork the two parallel processes
        fork
            collect_inputs();
            collect_outputs_and_send();
        join
    endtask

    virtual task collect_inputs();
        fp16_classify_transaction trans;
        // Wait for reset to finish
        @(posedge vif.rst_n);
        forever begin
            @(vif.monitor_cb);
            // Only capture the transaction if it's valid (not X)
            if (! (^vif.monitor_cb.in === 1'bx) ) begin
                trans = fp16_classify_transaction::type_id::create("trans_input");
                trans.in = vif.monitor_cb.in;
                input_queue.push_back(trans);
            end
        end
    endtask

    virtual task collect_outputs_and_send();
        fp16_classify_transaction trans_out;
        
        // Wait for reset to finish
        @(posedge vif.rst_n);
        // Wait for the exact pipeline latency to fill up *after* reset
        repeat(PIPELINE_LATENCY) @(vif.monitor_cb);

        forever begin
            @(vif.monitor_cb);
            if (input_queue.size() > 0) begin
                trans_out = input_queue.pop_front();
                trans_out.result.is_snan         = vif.monitor_cb.is_snan         ;
                trans_out.result.is_qnan         = vif.monitor_cb.is_qnan         ;
                trans_out.result.is_neg_inf      = vif.monitor_cb.is_neg_inf      ;
                trans_out.result.is_neg_normal   = vif.monitor_cb.is_neg_normal   ;
                trans_out.result.is_neg_denormal = vif.monitor_cb.is_neg_denormal ;
                trans_out.result.is_neg_zero     = vif.monitor_cb.is_neg_zero     ;
                trans_out.result.is_pos_zero     = vif.monitor_cb.is_pos_zero     ;
                trans_out.result.is_pos_denormal = vif.monitor_cb.is_pos_denormal ;
                trans_out.result.is_pos_normal   = vif.monitor_cb.is_pos_normal   ;
                trans_out.result.is_pos_inf      = vif.monitor_cb.is_pos_inf      ;
                `uvm_info("MONITOR", $sformatf("Collected transaction: in=0x%h, result=0x%h", trans_out.in, trans_out.result), UVM_HIGH)
                ap.write(trans_out);
            end
        end
    endtask

endclass
