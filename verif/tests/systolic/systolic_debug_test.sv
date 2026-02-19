// verif/tests/systolic/systolic_debug_test.sv
// Test that runs debug sequences (Identity, Sparse, etc).

`include "uvm_macros.svh"
import uvm_pkg::*;

class systolic_debug_test extends uvm_test;
    `uvm_component_utils(systolic_debug_test)

    // Parameters must match DUT/Top
    parameter ROWS = 2;
    parameter COLS = 2;
    parameter WIDTH = 4;
    parameter ACC_WIDTH = 9;

    systolic_env #(ROWS, COLS, WIDTH, ACC_WIDTH) env;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = systolic_env #(ROWS, COLS, WIDTH, ACC_WIDTH)::type_id::create("env", this);
    endfunction

    task run_phase(uvm_phase phase);
        systolic_debug_sequence #(ROWS, COLS, WIDTH, ACC_WIDTH) seq;
        
        phase.raise_objection(this);
        
        seq = systolic_debug_sequence #(ROWS, COLS, WIDTH, ACC_WIDTH)::type_id::create("seq");
        seq.start(env.agent.sequencer);
        
        #100ns; // Wait for last outputs
        phase.drop_objection(this);
    endtask
endclass