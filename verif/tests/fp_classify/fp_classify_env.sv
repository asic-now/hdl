// verif/tests/fp_classify/fp_classify_env.sv
// Top-level environment for the fp_classify testbench.

`include "uvm_macros.svh"
import uvm_pkg::*;

class fp_classify_env #(
    parameter int WIDTH = 16
) extends uvm_env;

    `uvm_component_param_utils(fp_classify_env #(WIDTH))

    fp_classify_agent #(WIDTH) agent;
    fp_classify_model #(WIDTH) model;
    base_scoreboard #(fp_classify_transaction #(WIDTH), fp_classify_model #(WIDTH)) scoreboard; // Using the generic scoreboard

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agent = fp_classify_agent #(WIDTH)::type_id::create("agent", this);
        model = fp_classify_model #(WIDTH)::type_id::create("model", this);
        scoreboard = base_scoreboard #(fp_classify_transaction #(WIDTH), fp_classify_model #(WIDTH))::type_id::create("scoreboard", this);

        // Pass the model handle to all children of this component
        uvm_config_db#(fp_classify_model #(WIDTH))::set(this, "*", "model", model);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        agent.monitor.ap.connect(scoreboard.ap);
    endfunction

endclass
