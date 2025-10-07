// verif/tests/fp_add/fp_add_env.sv
// Parameterized UVM environment for the fp_add testbench.

`include "uvm_macros.svh"
import uvm_pkg::*;

class fp_add_env #(
    parameter int WIDTH = 16
) extends uvm_env;

    `uvm_component_param_utils(fp_add_env #(WIDTH))

    // Components
    fp_add_agent #(WIDTH) agent;
    fp_add_model #(WIDTH) model;
    base_scoreboard #(fp_transaction2 #(WIDTH), fp_add_model #(WIDTH)) scoreboard; // Using the generic scoreboard

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agent = fp_add_agent #(WIDTH)::type_id::create("agent", this);
        model = fp_add_model #(WIDTH)::type_id::create("model", this);
        scoreboard = base_scoreboard #(fp_transaction2 #(WIDTH), fp_add_model #(WIDTH))::type_id::create("scoreboard", this);

        // Pass the model handle to all children of this component
        uvm_config_db#(fp_add_model#(WIDTH))::set(this, "*", "model", model);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        agent.monitor.ap.connect(scoreboard.ap);
    endfunction

endclass
