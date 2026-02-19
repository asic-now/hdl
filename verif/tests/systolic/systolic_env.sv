// verif/tests/systolic/systolic_env.sv
// Parameterized UVM environment for the systolic DUT.

`include "uvm_macros.svh"
import uvm_pkg::*;

class systolic_env #(
    parameter ROWS = 2,
    parameter COLS = 2,
    parameter WIDTH = 4,
    parameter ACC_WIDTH = 9
) extends uvm_env;

    `uvm_component_param_utils(systolic_env #(ROWS, COLS, WIDTH, ACC_WIDTH))

    systolic_agent #(ROWS, COLS, WIDTH, ACC_WIDTH) agent;
    systolic_scoreboard #(ROWS, COLS, WIDTH, ACC_WIDTH) scoreboard;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agent = systolic_agent #(ROWS, COLS, WIDTH, ACC_WIDTH)::type_id::create("agent", this);
        scoreboard = systolic_scoreboard #(ROWS, COLS, WIDTH, ACC_WIDTH)::type_id::create("scoreboard", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        agent.monitor.ap_in.connect(scoreboard.port_in);
        agent.monitor.ap_out.connect(scoreboard.port_out);
    endfunction

endclass
