// fp16_add_tb_top.sv
// Top-level module for the fp16_add testbench.

`include "uvm_macros.svh"
import uvm_pkg::*;
import fp16_add_pkg::*; // Import the DUT-specific test package

module fp16_add_tb_top;
    // Clock and Reset signals
    bit clk;
    bit rst_n;

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

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 10ns period, 100MHz clock
    end

    // Reset generation
    initial begin
        rst_n = 0;
        repeat(5) @(posedge clk);
        rst_n = 1;
    end

    // UVM test runner
    initial begin
        // Place the interface into the UVM configuration database
        // so components in the environment can access it.
        uvm_config_db#(virtual fp16_add_if)::set(null, "uvm_test_top", "dut_vif", dut_if);
        
        // The default test is fp16_add_random_test, which is defined in fp16_add_pkg.sv.
        // This can be overridden on the command line, e.g., +UVM_TESTNAME=my_other_test
        run_test();
    end

endmodule
