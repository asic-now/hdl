// verif/tests/systolic/systolic_scoreboard.sv
// Parameterized UVM scoreboard for the systolic DUT.

`include "uvm_macros.svh"
import uvm_pkg::*;

`uvm_analysis_imp_decl(_in)
`uvm_analysis_imp_decl(_out)

class systolic_scoreboard #(
    parameter ROWS = 2,
    parameter COLS = 2,
    parameter WIDTH = 4,
    parameter ACC_WIDTH = 9
) extends uvm_scoreboard;

    `uvm_component_param_utils(systolic_scoreboard #(ROWS, COLS, WIDTH, ACC_WIDTH))

    uvm_analysis_imp_in #(systolic_item #(ROWS, COLS, WIDTH, ACC_WIDTH), systolic_scoreboard #(ROWS, COLS, WIDTH, ACC_WIDTH)) port_in;
    uvm_analysis_imp_out #(systolic_item #(ROWS, COLS, WIDTH, ACC_WIDTH), systolic_scoreboard #(ROWS, COLS, WIDTH, ACC_WIDTH)) port_out;

    systolic_item #(ROWS, COLS, WIDTH, ACC_WIDTH) exp_queue[$];

    function new(string name, uvm_component parent);
        super.new(name, parent);
        port_in = new("port_in", this);
        port_out = new("port_out", this);
    endfunction

    // Input Analysis Port Write
    function void write_in(systolic_item #(ROWS, COLS, WIDTH, ACC_WIDTH) t);
        systolic_item #(ROWS, COLS, WIDTH, ACC_WIDTH) exp_item;
        exp_item = systolic_item #(ROWS, COLS, WIDTH, ACC_WIDTH)::type_id::create("exp_item");
        exp_item.copy(t);
        
        // Calculate Expected Result (Matrix Multiplication)
        for (int i = 0; i < ROWS; i++) begin
            for (int j = 0; j < COLS; j++) begin
                int sum = 0;
                for (int k = 0; k < ROWS; k++) begin
                    sum += t.a_matrix[i][k] * t.b_matrix[k][j];
                end
                exp_item.c_matrix[i][j] = sum;
            end
        end
        
        exp_queue.push_back(exp_item);
    endfunction

    // Output Analysis Port Write
    function void write_out(systolic_item #(ROWS, COLS, WIDTH, ACC_WIDTH) t);
        systolic_item #(ROWS, COLS, WIDTH, ACC_WIDTH) exp_item;
        
        if (exp_queue.size() == 0) begin
            `uvm_error("SCB", "Unexpected output transaction received")
            return;
        end

        exp_item = exp_queue.pop_front();

        // Compare
        for (int i = 0; i < ROWS; i++) begin
            for (int j = 0; j < COLS; j++) begin
                if (t.c_matrix[i][j] !== exp_item.c_matrix[i][j]) begin
                    `uvm_error("SCB", $sformatf("Mismatch at [%0d][%0d]. Exp: %0d, Act: %0d", 
                        i, j, exp_item.c_matrix[i][j], t.c_matrix[i][j]))
                end
            end
        end
        `uvm_info("SCB", "Transaction verified successfully", UVM_HIGH)
    endfunction

endclass
