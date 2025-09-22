// verif/tests/fp16_classify/fp16_classify_env.sv
// Top-level environment for the fp16_classify testbench.

`include "uvm_macros.svh"
import uvm_pkg::*;

class fp16_classify_env extends uvm_env;
    `uvm_component_utils(fp16_classify_env)

    fp16_classify_agent agent;
    fp16_classify_model model;
    base_scoreboard #(fp16_classify_transaction, fp16_classify_model) scoreboard; // Using the generic scoreboard

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agent = fp16_classify_agent::type_id::create("agent", this);
        model = fp16_classify_model::type_id::create("model"); // model has no parent
        scoreboard = base_scoreboard #(fp16_classify_transaction, fp16_classify_model)::type_id::create("scoreboard", this);

        // Pass the model handle to all children of this component
        uvm_config_db#(fp16_classify_model)::set(this, "*", "model", model);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        agent.monitor.ap.connect(scoreboard.ap);
    endfunction

endclass
