// verif/tests/systolic/systolic_sequence.sv
// Parameterized UVM sequence for the systolic DUT.

`include "uvm_macros.svh"
import uvm_pkg::*;

class systolic_random_sequence #(
    parameter ROWS = 2,
    parameter COLS = 2,
    parameter WIDTH = 4,
    parameter ACC_WIDTH = 9
) extends uvm_sequence #(systolic_item #(ROWS, COLS, WIDTH, ACC_WIDTH));

    `uvm_object_param_utils(systolic_random_sequence #(ROWS, COLS, WIDTH, ACC_WIDTH))

    function new(string name = "systolic_random_sequence");
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

class systolic_debug_sequence #(
    parameter ROWS = 2,
    parameter COLS = 2,
    parameter WIDTH = 4,
    parameter ACC_WIDTH = 9
) extends uvm_sequence #(systolic_item #(ROWS, COLS, WIDTH, ACC_WIDTH));

    `uvm_object_param_utils(systolic_debug_sequence #(ROWS, COLS, WIDTH, ACC_WIDTH))

    function new(string name = "systolic_debug_sequence");
        super.new(name);
    endfunction

    task body();
        systolic_item #(ROWS, COLS, WIDTH, ACC_WIDTH) item;
        
        // Case 1: Identity x Identity
        `uvm_info("SEQ", "Generating Identity x Identity", UVM_LOW)
        item = systolic_item #(ROWS, COLS, WIDTH, ACC_WIDTH)::type_id::create("item_identity");
        start_item(item);
        assert(item.randomize() with {
            foreach(a_matrix[i,j]) a_matrix[i][j] == (i==j ? 1 : 0);
            foreach(b_matrix[i,j]) b_matrix[i][j] == (i==j ? 1 : 0);
        });
        finish_item(item);

        // Case 2: Sparse (A[0][0]=1, B[0][0]=1, others 0)
        `uvm_info("SEQ", "Generating Sparse [0][0]", UVM_LOW)
        item = systolic_item #(ROWS, COLS, WIDTH, ACC_WIDTH)::type_id::create("item_sparse");
        start_item(item);
        assert(item.randomize() with {
            foreach(a_matrix[i,j]) a_matrix[i][j] == (i==0 && j==0 ? 1 : 0);
            foreach(b_matrix[i,j]) b_matrix[i][j] == (i==0 && j==0 ? 1 : 0);
        });
        finish_item(item);

        // Case 3: Full 1s
        `uvm_info("SEQ", "Generating All 1s", UVM_LOW)
        item = systolic_item #(ROWS, COLS, WIDTH, ACC_WIDTH)::type_id::create("item_ones");
        start_item(item);
        assert(item.randomize() with {
            foreach(a_matrix[i,j]) a_matrix[i][j] == 1;
            foreach(b_matrix[i,j]) b_matrix[i][j] == 1;
        });
        finish_item(item);

    endtask

endclass
