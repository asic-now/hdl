// verif/tests/systolic/systolic_if.sv
// Parameterized UVM interface for the systolic DUT.

interface systolic_if #(
    parameter ROWS = 2,
    parameter COLS = 2,
    parameter WIDTH = 4,
    parameter ACC_WIDTH = 9
) (
    input logic clk,
    input logic rst_n
);
    logic [ROWS*ROWS*WIDTH-1:0] a;
    logic [ROWS*COLS*WIDTH-1:0] b;
    logic in_valid;
    logic in_ready;
    logic [ROWS*COLS*ACC_WIDTH-1:0] c;
    logic out_valid;

    clocking cb_drv @(posedge clk);
        output a, b, in_valid;
        input  in_ready;
    endclocking

    clocking cb_mon @(posedge clk);
        input a, b, in_valid, in_ready, c, out_valid;
    endclocking

endinterface
