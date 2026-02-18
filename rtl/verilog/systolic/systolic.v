/*
 * Systolic Array Block
 */
module systolic #(
    parameter ROWS = 2,
    parameter COLS = 2,
    parameter WIDTH = 4,
    parameter ACC_WIDTH = 9,
    parameter MUL_LATENCY = 0,
    parameter ADD_LATENCY = 1
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [ROWS*ROWS*WIDTH-1:0] a, // Flattened A matrix
    input  wire [ROWS*COLS*WIDTH-1:0] b, // Flattened B matrix
    input  wire       in_valid,  // Strobe input data into buffers
    output wire       in_ready,  // Indicates input buffers can accept new data
    output wire [ROWS*COLS*ACC_WIDTH-1:0] c, // Flattened C matrix
    output wire       out_valid  // Indicates output data is ready to be read
);

    wire b_load, b_update, b_update_done;
    wire [ROWS*WIDTH-1:0] a_row;
    wire [COLS*WIDTH-1:0] b_col;
    wire [COLS*ACC_WIDTH-1:0] c_col;

    systolic_controller #(
        .ROWS(ROWS),
        .COLS(COLS),
        .WIDTH(WIDTH),
        .ACC_WIDTH(ACC_WIDTH),
        .MUL_LATENCY(MUL_LATENCY),
        .ADD_LATENCY(ADD_LATENCY)
    ) controller (
        .clk(clk), .rst_n(rst_n),
        .in_valid(in_valid),
        .in_ready(in_ready),
        .a_flat(a),
        .b_flat(b),
        .b_load(b_load), .b_update(b_update), .b_update_done(b_update_done),
        .a_row_flat(a_row),
        .b_col_flat(b_col),
        .c_col_flat(c_col),
        .c_flat(c),
        .out_valid(out_valid)
    );

    systolic_array #(
        .ROWS(ROWS),
        .COLS(COLS),
        .WIDTH(WIDTH),
        .ACC_WIDTH(ACC_WIDTH),
        .MUL_LATENCY(MUL_LATENCY),
        .ADD_LATENCY(ADD_LATENCY)
    ) array (
        .clk(clk), .rst_n(rst_n),
        .b_load(b_load), .b_update(b_update), .b_update_done(b_update_done),
        .a_row(a_row),
        .b_col(b_col),
        .c_col(c_col)
    );

endmodule