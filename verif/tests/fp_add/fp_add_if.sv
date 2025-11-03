// verif/tests/fp_add/fp_add_if.sv
// Parameterized interface for the fp_add DUT.

interface fp_add_if #(
    parameter int WIDTH = 16
) (
    input bit clk,
    input logic rst_n
);
    // DUT Inputs
    logic [WIDTH-1:0] a;
    logic [WIDTH-1:0] b;
    logic [2:0]       rm;

    // DUT Outputs
    logic [WIDTH-1:0] result;

    // Clocking block for the driver
    clocking driver_cb @(posedge clk);
        default input #1step output #1ns;
        output a, b, rm;
    endclocking

    // Clocking block for the monitor
    clocking monitor_cb @(posedge clk);
        default input #1step output #1ns;
        input a, b, rm, result;
    endclocking

    // Modport for the driver
    modport DRIVER (clocking driver_cb, input rst_n);
    // Modport for the monitor
    modport MONITOR (clocking monitor_cb, input rst_n);

endinterface
