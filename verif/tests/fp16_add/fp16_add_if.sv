// verif/tests/fp16_add/fp16_add_if.sv
// Interface for the fp16_add DUT.

interface fp16_add_if (
    input bit clk,
    input logic rst_n
);
    // DUT Inputs
    logic [15:0] a;
    logic [15:0] b;
    
    // DUT Outputs
    logic [15:0] result;

    // Clocking block for the driver
    clocking driver_cb @(posedge clk);
        default input #1step output #1ns;
        output a, b;
    endclocking

    // Clocking block for the monitor
    clocking monitor_cb @(posedge clk);
        default input #1step output #1ns;
        input a, b, result;
    endclocking

    // Modport for the driver
    modport DRIVER (clocking driver_cb, input rst_n);
    // Modport for the monitor
    modport MONITOR (clocking monitor_cb, input rst_n);

endinterface
