// fp16_add_monitor.sv
// Monitors the DUT interface and reports transactions.

`include "uvm_macros.svh"
import uvm_pkg::*;

class fp16_add_monitor extends uvm_monitor;
    `uvm_component_utils(fp16_add_monitor)

    virtual fp16_add_if vif;
    uvm_analysis_port #(fp16_add_transaction) ap;

    // A queue to store input transactions and align them with the pipelined output
    fp16_add_transaction input_queue[$];
    
    local static const int PIPELINE_LATENCY = 3;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(virtual fp16_add_if)::get(this, "", "dut_vif", vif))
            `uvm_fatal("NOVIF", "Could not get virtual interface handle")
    endfunction

    virtual task run_phase(uvm_phase phase);
        // Wait for reset to finish before starting any monitoring
        @(posedge vif.rst_n);

        // Fork the two parallel processes
        fork
            collect_inputs();
            collect_outputs_and_send();
        join
    endtask

    virtual task collect_inputs();
        fp16_add_transaction trans;
        forever begin
            @(vif.monitor_cb);
            // Only capture the transaction if it's valid (not X)
            if (! (^vif.monitor_cb.a === 1'bx) && ! (^vif.monitor_cb.b === 1'bx)) begin
                 trans = fp16_add_transaction::type_id::create("trans_input");
                 trans.a = vif.monitor_cb.a;
                 trans.b = vif.monitor_cb.b;
                 input_queue.push_back(trans);
            end
        end
    endtask

    virtual task collect_outputs_and_send();
        fp16_add_transaction trans_out;
        
        // Wait for the pipeline to fill with valid data after reset
        repeat(PIPELINE_LATENCY) @(vif.monitor_cb);

        forever begin
            @(vif.monitor_cb);
            if (input_queue.size() > 0) begin
                trans_out = input_queue.pop_front();
                trans_out.result = vif.monitor_cb.result;
                `uvm_info("MONITOR", $sformatf("Collected transaction: a=0x%h, b=0x%h, result=0x%h", trans_out.a, trans_out.b, trans_out.result), UVM_HIGH)
                ap.write(trans_out);
            end
        end
    endtask

endclass
