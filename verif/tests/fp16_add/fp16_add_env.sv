// fp16_add_env.sv
// Top-level environment for the fp16_add test.

`include "uvm_macros.svh"
import uvm_pkg::*;

class fp16_add_env extends uvm_env;
    `uvm_component_utils(fp16_add_env)

    fp16_add_agent agent;
    fp16_add_model model;
    fp_scoreboard #(fp16_add_transaction) scbd; // Using the generic scoreboard

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agent = fp16_add_agent::type_id::create("agent", this);
        model = fp16_add_model::type_id::create("model", this);
        scbd  = fp_scoreboard #(fp16_add_transaction)::type_id::create("scbd", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        agent.mon.ap.connect(scbd.actual_export);
        agent.mon.ap.connect(model.port);
        model.ap.connect(scbd.expected_fifo.analysis_export);
    endfunction
endclass
