// verif/tests/systolic/systolic_agent.sv
// Parameterized UVM agent for the systolic DUT.

`include "uvm_macros.svh"
import uvm_pkg::*;

class systolic_agent #(
    parameter ROWS = 2,
    parameter COLS = 2,
    parameter WIDTH = 4,
    parameter ACC_WIDTH = 9
) extends uvm_agent;

    `uvm_component_param_utils(systolic_agent #(ROWS, COLS, WIDTH, ACC_WIDTH))

    uvm_sequencer #(systolic_item #(ROWS, COLS, WIDTH, ACC_WIDTH)) sequencer;
    systolic_driver #(ROWS, COLS, WIDTH, ACC_WIDTH) driver;
    systolic_monitor #(ROWS, COLS, WIDTH, ACC_WIDTH) monitor;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        monitor = systolic_monitor #(ROWS, COLS, WIDTH, ACC_WIDTH)::type_id::create("monitor", this);
        if (get_is_active() == UVM_ACTIVE) begin
            sequencer = uvm_sequencer #(systolic_item #(ROWS, COLS, WIDTH, ACC_WIDTH))::type_id::create("sequencer", this);
            driver = systolic_driver #(ROWS, COLS, WIDTH, ACC_WIDTH)::type_id::create("driver", this);
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        if (get_is_active() == UVM_ACTIVE) begin
            driver.seq_item_port.connect(sequencer.seq_item_export);
        end
    endfunction

endclass
