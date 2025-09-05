// fp16_add_agent.sv
// DUT-specific agent.

`include "uvm_macros.svh"
import uvm_pkg::*;

class fp16_add_agent extends uvm_agent;
    `uvm_component_utils(fp16_add_agent)

    fp16_add_driver drv;
    uvm_sequencer #(fp16_add_transaction) sqr;
    fp16_add_monitor mon;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        sqr = uvm_sequencer #(fp16_add_transaction)::type_id::create("sqr", this);
        drv = fp16_add_driver::type_id::create("drv", this);
        mon = fp16_add_monitor::type_id::create("mon", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction
endclass
