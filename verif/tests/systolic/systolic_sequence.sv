// verif/tests/systolic/systolic_sequence.sv
// Parameterized UVM sequence for the systolic DUT.

`include "uvm_macros.svh"
import uvm_pkg::*;

class systolic_sequence #(
    parameter ROWS = 2,
    parameter COLS = 2,
    parameter WIDTH = 4,
    parameter ACC_WIDTH = 9
) extends uvm_sequence #(systolic_item #(ROWS, COLS, WIDTH, ACC_WIDTH));

    `uvm_object_param_utils(systolic_sequence #(ROWS, COLS, WIDTH, ACC_WIDTH))

    function new(string name = "systolic_sequence");
        super.new(name);
    endfunction

    task body();
        systolic_item #(ROWS, COLS, WIDTH, ACC_WIDTH) item;
        repeat(20) begin
            item = systolic_item #(ROWS, COLS, WIDTH, ACC_WIDTH)::type_id::create("item");
            start_item(item);
            if (!item.randomize()) `uvm_error("SEQ", "Randomization failed");
            finish_item(item);
        end
    endtask

endclass
