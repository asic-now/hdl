// fp16_classify_if.sv
// Interface for the fp16_classify DUT.

interface fp16_classify_if (
    input bit clk,
    input logic rst_n
);
    // DUT Inputs
    logic [15:0] in;
    
    // DUT Outputs
    logic is_snan;
    logic is_qnan;
    logic is_neg_inf;
    logic is_neg_normal;
    logic is_neg_denormal;
    logic is_neg_zero;
    logic is_pos_zero;
    logic is_pos_denormal;
    logic is_pos_normal;
    logic is_pos_inf;

    // Clocking block for the driver
    clocking driver_cb @(posedge clk);
        default input #1step output #1ns;
        output in;
    endclocking

    // Clocking block for the monitor
    clocking monitor_cb @(posedge clk);
        default input #1step output #1ns;
        input in, 
           is_snan,
           is_qnan,
           is_neg_inf,
           is_neg_normal,
           is_neg_denormal,
           is_neg_zero,
           is_pos_zero,
           is_pos_denormal,
           is_pos_normal,
           is_pos_inf
        ;
    endclocking

    // Modport for the driver
    modport DRIVER (clocking driver_cb, input rst_n);
    // Modport for the monitor
    modport MONITOR (clocking monitor_cb, input rst_n);

endinterface
