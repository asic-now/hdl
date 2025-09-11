// fp16_add_monitor.sv
// DUT-specific monitor.

`include "uvm_macros.svh"
import uvm_pkg::*;

class fp16_add_monitor extends uvm_monitor;
    `uvm_component_utils(fp16_add_monitor)

    virtual fp16_add_if vif;
    uvm_analysis_port #(fp16_add_transaction) ap;

    localparam DUT_LATENCY = 3;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual fp16_add_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal("NOVIF", "Virtual interface must be set for monitor!")
        end
    endfunction

    virtual task run_phase(uvm_phase phase);
        fp16_add_transaction tx_q[$];

        forever begin
            @(vif.cb);
            if (vif.rst_n) begin
                fp16_add_transaction new_tx = fp16_add_transaction::type_id::create("new_tx");
                new_tx.a = vif.a;
                new_tx.b = vif.b;
                tx_q.push_back(new_tx);
                
                if (tx_q.size() > DUT_LATENCY) begin
                    fp16_add_transaction captured_tx = tx_q.pop_front();
                    captured_tx.result = vif.result;
                    ap.write(captured_tx);
                end
            end else begin
                tx_q.delete();
            end
        end
    endtask
endclass
