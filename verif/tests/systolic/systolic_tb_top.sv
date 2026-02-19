module systolic_tb_top;
    import uvm_pkg::*;
    import systolic_pkg::*;

    parameter ROWS = 2;
    parameter COLS = 2;
    parameter WIDTH = 4;
    parameter ACC_WIDTH = 9;
    parameter MUL_LATENCY = 0;
    parameter ADD_LATENCY = 1;

    logic clk;
    logic rst_n;

    // Interface
    systolic_if #(
        .ROWS(ROWS),
        .COLS(COLS),
        .WIDTH(WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
    ) intf (
        .clk(clk),
        .rst_n(rst_n)
    );

    systolic #(
        .ROWS(ROWS),
        .COLS(COLS),
        .WIDTH(WIDTH),
        .ACC_WIDTH(ACC_WIDTH),
        .MUL_LATENCY(MUL_LATENCY),
        .ADD_LATENCY(ADD_LATENCY)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .a(intf.a),
        .b(intf.b),
        .in_valid(intf.in_valid),
        .in_ready(intf.in_ready),
        .c(intf.c),
        .out_valid(intf.out_valid)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        rst_n = 0;
        #20;
        rst_n = 1;
    end

    initial begin
        uvm_config_db#(virtual systolic_if #(ROWS, COLS, WIDTH, ACC_WIDTH))::set(null, "*", "vif", intf);
        run_test();
    end

endmodule