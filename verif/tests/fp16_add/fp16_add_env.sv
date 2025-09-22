// verif/tests/fp16_add/fp16_add_env.sv
// Top-level environment for the fp16_add testbench.

`include "uvm_macros.svh"
import uvm_pkg::*;

class fp16_add_env extends uvm_env;
    `uvm_component_utils(fp16_add_env)

    fp16_add_agent agent;
    fp16_add_model model;
    base_scoreboard #(fp16_add_transaction, fp16_add_model) scoreboard; // Using the generic scoreboard

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agent = fp16_add_agent::type_id::create("agent", this);
        model = fp16_add_model::type_id::create("model"); // model has no parent
        scoreboard = base_scoreboard #(fp16_add_transaction, fp16_add_model)::type_id::create("scoreboard", this);

        // Pass the model handle to all children of this component
        uvm_config_db#(fp16_add_model)::set(this, "*", "model", model);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        agent.monitor.ap.connect(scoreboard.ap);
    endfunction

endclass
