// fp16_add_monitor.sv
// Monitors the DUT interface and reports transactions.

`include "uvm_macros.svh"
import uvm_pkg::*;

class fp16_add_monitor extends uvm_monitor;
    `uvm_component_utils(fp16_add_monitor)

    virtual fp16_add_if vif;
    uvm_analysis_port #(fp16_add_transaction) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(virtual fp16_add_if)::get(this, "", "dut_vif", vif)) begin
            `uvm_fatal("NOVIF", "Could not get virtual interface handle")
        end
    endfunction

    virtual task run_phase(uvm_phase phase);
        forever begin
            collect_transaction();
        end
    endtask

    virtual task collect_transaction();
        fp16_add_transaction trans;
        trans = fp16_add_transaction::type_id::create("trans");

        // 1. Wait for valid inputs to appear
        @(vif.monitor_cb);
        
        // 2. Sample the inputs
        trans.a = vif.monitor_cb.a;
        trans.b = vif.monitor_cb.b;
        
        // 3. Wait for the 3-cycle pipeline latency of the DUT
        repeat(3) @(vif.monitor_cb);
        
        // 4. Sample the corresponding result
        trans.result = vif.monitor_cb.result;

        `uvm_info("MONITOR", $sformatf("Collected transaction: a=0x%h, b=0x%h, result=0x%h", trans.a, trans.b, trans.result), UVM_HIGH)
        ap.write(trans);
    endtask

endclass
