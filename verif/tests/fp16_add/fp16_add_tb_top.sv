// verif/tests/fp16_add/fp16_add_tb_top.sv
// Top-level module for the fp16_add UVM testbench.

`include "uvm_macros.svh"
import uvm_pkg::*;
import fp16_add_pkg::*; // Import the DUT-specific test package

module fp16_add_tb_top;
    // Clock and Reset signals
    bit clk;
    logic rst_n;

    // Instantiate the DUT interface
    fp16_add_if dut_if(clk, rst_n);

    // Instantiate the DUT
    fp16_add dut (
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

    // Set the interface in the config DB for the test
    initial begin
        // Use "uvm_test_top.*" to make the interface visible to all TB components
        uvm_config_db#(virtual fp16_add_if)::set(null, "uvm_test_top.*", "dut_vif", dut_if);
        run_test(); // run_test() with no args uses +UVM_TESTNAME
    end

endmodule
