// fp16_classify_tb_top.sv
// Top-level module for the fp16_classify UVM testbench.

`include "uvm_macros.svh"
import uvm_pkg::*;
import fp16_classify_pkg::*; // Import the DUT-specific test package

module fp16_classify_tb_top;
    // Clock and Reset signals
    bit clk;
    logic rst_n;

    // Instantiate the DUT interface
    fp16_classify_if dut_if(clk, rst_n);
    // fp16_classify_if dut_if(clk);

    // Instantiate the DUT
    fp16_classify dut (
        // .clk(dut_if.clk),
        // .rst_n(dut_if.rst_n),
        .in(dut_if.in),
        // .result(dut_if.result)
        .is_snan          (dut_if.is_snan          ),          // Signaling Not a Number
        .is_qnan          (dut_if.is_qnan          ),          // Quiet Not a Number
        .is_neg_inf       (dut_if.is_neg_inf       ),       // Negative Infinity
        .is_neg_normal    (dut_if.is_neg_normal    ),    // Negative Normal Number
        .is_neg_denormal  (dut_if.is_neg_denormal  ),  // Negative Denormalized Number
        .is_neg_zero      (dut_if.is_neg_zero      ),      // Negative Zero
        .is_pos_zero      (dut_if.is_pos_zero      ),      // Positive Zero
        .is_pos_denormal  (dut_if.is_pos_denormal  ),  // Positive Denormalized Number
        .is_pos_normal    (dut_if.is_pos_normal    ),    // Positive Normal Number
        .is_pos_inf       (dut_if.is_pos_inf       )// Positive Infinity
    );

    // Clock generator
    initial begin
        clk = 0;
        forever #5ns clk = ~clk; // 10ns period, 100MHz clock
    end

    // Reset generator
    initial begin
        rst_n = 0;
        repeat(5) @(negedge clk);
        rst_n = 1;
    end

    // Set the interface in the config DB for the test
    initial begin
        // Use "uvm_test_top.*" to make the interface visible to all components
        uvm_config_db#(virtual fp16_classify_if)::set(null, "uvm_test_top.*", "dut_vif", dut_if);
        run_test(); // run_test() with no args uses +UVM_TESTNAME
    end

endmodule
