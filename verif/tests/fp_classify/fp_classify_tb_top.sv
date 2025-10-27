// verif/tests/fp_classify/fp_classify_tb_top.sv
// Parameterized testbench top for the fp_classify DUT.

`include "uvm_macros.svh"
import uvm_pkg::*;
import fp_classify_pkg::*; // Import the DUT-specific test package

module fp_classify_tb_top;
    // The WIDTH parameter is passed from the compile command line (e.g., -g WIDTH=16)
    parameter int WIDTH = 16;

    // Clock and Reset signals
    bit clk;
    logic rst_n;

    // Instantiate the DUT interface
    fp_classify_if  #(WIDTH) dut_if(clk, rst_n);

    // Instantiate the DUT
    fp_classify #(WIDTH) dut (
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
    `VERIF_GET_DUT_PIPELINE(dut)

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

    // Define each test component that this testbench can be ran with (using +UVM_TESTNAME=...)
    typedef fp_classify_special_cases_test #(WIDTH) fp_classify_special_cases_test_t;
    typedef fp_classify_random_test        #(WIDTH) fp_classify_random_test_t;
    typedef fp_classify_combined_test      #(WIDTH) fp_classify_combined_test_t;

    // Main test execution block
    initial begin
        // Set the interface in the UVM configuration database for the tests to use
        // Use "uvm_test_top.*" to make the interface visible to all TB components
        uvm_config_db#(virtual fp_classify_if #(WIDTH))::set(null, "uvm_test_top.*", "dut_vif", dut_if);
        run_test(); // run_test() with no args uses +UVM_TESTNAME
    end

endmodule
