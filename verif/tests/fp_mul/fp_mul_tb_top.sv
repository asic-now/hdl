// verif/tests/fp_mul/fp_mul_tb_top.sv
// Parameterized testbench top for the fp_mul DUT.

`include "uvm_macros.svh"
import uvm_pkg::*;
import fp_mul_pkg::*; // Import the DUT-specific test package

module fp_mul_tb_top;
    // The WIDTH parameter is passed from the compile command line (e.g., -g WIDTH=16)
    parameter int WIDTH = 16;

    // Clock and Reset signals
    bit clk;
    logic rst_n;

    // Instantiate the DUT interface
    fp_mul_if #(WIDTH) dut_if (clk, rst_n);

    // Instantiate the DUT
    fp_mul #(WIDTH) dut (
        .clk(dut_if.clk),
        .rst_n(dut_if.rst_n),
        .a(dut_if.a),
        .b(dut_if.b),
        .result(dut_if.result)
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
    typedef fp_mul_special_cases_test #(WIDTH) fp_mul_special_cases_test_t;
    typedef fp_mul_random_test        #(WIDTH) fp_mul_random_test_t;
    typedef fp_mul_combined_test      #(WIDTH) fp_mul_combined_test_t;

    // Main test execution block
    initial begin
        // Set the interface in the UVM configuration database for the tests to use
        uvm_config_db#(virtual fp_mul_if#(WIDTH))::set(null, "uvm_test_top.*", "dut_vif", dut_if);
        // uvm_config_db#(virtual fp_mul_if#(WIDTH))::set(null, "uvm_test_top.env.agent", "dut_vif", dut_if);

        // Run the test specified by +UVM_TESTNAME on the command line
        run_test();
    end

endmodule
