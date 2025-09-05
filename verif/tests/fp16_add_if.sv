// fp16_add_if.sv
// SystemVerilog interface for the fp16_add DUT.

interface fp16_add_if(input bit clk);
    logic rst_n;
    logic [15:0] a;
    logic [15:0] b;
    logic [15:0] result;

    clocking cb @(posedge clk);
        default input #1step output #1ns;
        output a, b, rst_n;
        input result;
    endclocking
endinterface
