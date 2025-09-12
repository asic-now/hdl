// fp16_add_agent.sv
// UVM Agent for the fp16_add DUT.

`include "uvm_macros.svh"
import uvm_pkg::*;

class fp16_add_agent extends uvm_agent;
    `uvm_component_utils(fp16_add_agent)

    fp16_add_driver driver;
    fp16_add_monitor monitor;
    uvm_sequencer #(fp16_add_transaction) seqr;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        monitor = fp16_add_monitor::type_id::create("monitor", this);
        if(get_is_active() == UVM_ACTIVE) begin
            driver = fp16_add_driver::type_id::create("driver", this);
            seqr = uvm_sequencer #(fp16_add_transaction)::type_id::create("seqr", this);
        end
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        if(get_is_active() == UVM_ACTIVE) begin
            driver.seq_item_port.connect(seqr.seq_item_export);
        end
    endfunction

endclass
