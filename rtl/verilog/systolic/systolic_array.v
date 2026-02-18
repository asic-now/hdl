/*
 * 2x2 Systolic Array
 * Instantiates 4 PEs in a 2*2 grid.
 */
module systolic_array #(
    parameter ROWS = 2,
    parameter COLS = 2,
    parameter WIDTH = 4,
    parameter ACC_WIDTH = 9,
    parameter MUL_LATENCY = 0,
    parameter ADD_LATENCY = 1
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       b_load,
    input  wire       b_update,
    // Row inputs for A (Activation) - Flattened
    input  wire [ROWS*WIDTH-1:0] a_row,
    // Column inputs for B (Weight loading) - Flattened
    input  wire [COLS*WIDTH-1:0] b_col,
    // Column outputs for C (Result) - Flattened
    output wire [COLS*ACC_WIDTH-1:0] c_col,
    output wire       b_update_done
);

    localparam ALU_LATENCY = MUL_LATENCY + ADD_LATENCY;

    // Interconnect wires
    // a_wire[i][j] connects PE(i,j-1) to PE(i,j)
    // b_wire[i][j] connects PE(i-1,j) to PE(i,j)
    // c_wire[i][j] connects PE(i-1,j) to PE(i,j)
    
    wire [WIDTH-1:0] a_wire [ROWS-1:0][COLS:0];
    wire [WIDTH-1:0] b_wire [ROWS:0][COLS-1:0];
    wire [ACC_WIDTH-1:0] c_wire [ROWS:0][COLS-1:0];

    // Staggered b_update signals
    // [i][0] is the input to the row, [i][j+1] is the output from PE(i,j)
    wire b_update_chain [ROWS-1:0][COLS:0];

    genvar i, j;
    generate
        // b_update propagation logic
        // (0,0) receives the global signal
        assign b_update_done = b_update_chain[ROWS-1][COLS];

        assign b_update_chain[0][0] = b_update;

        // Vertical propagation for Column 0 (Row 1 to ROWS-1)
        // Delays match ADD_LATENCY to align with row start times (skewed by controller)
        for (i = 1; i < ROWS; i = i + 1) begin : v_prop
            if (ADD_LATENCY == 0) begin
                 assign b_update_chain[i][0] = b_update_chain[i-1][0];
            end else begin : delay_logic
                 reg [ADD_LATENCY-1:0] v_sr;
                 if (ADD_LATENCY == 1) begin : lat1
                     always @(posedge clk or negedge rst_n) begin
                         if (!rst_n) v_sr <= 1'b0;
                         else v_sr <= b_update_chain[i-1][0];
                     end
                 end else begin : lat_n
                     always @(posedge clk or negedge rst_n) begin
                         if (!rst_n) v_sr <= {ADD_LATENCY{1'b0}};
                         else v_sr <= {v_sr[ALU_LATENCY-2:0], b_update_chain[i-1][0]};
                     end
                 end
                 assign b_update_chain[i][0] = v_sr[ADD_LATENCY-1];
            end
        end

        // Horizontal propagation is handled by the PEs themselves via b_update_out

        // Assign inputs to the edges
        for (i = 0; i < ROWS; i = i + 1) begin : row_inputs
            assign a_wire[i][0] = a_row[i*WIDTH +: WIDTH];
        end
        for (j = 0; j < COLS; j = j + 1) begin : col_inputs
            assign b_wire[0][j] = b_col[j*WIDTH +: WIDTH];
            assign c_wire[0][j] = {ACC_WIDTH{1'b0}}; // Top C input is 0
            assign c_col[j*ACC_WIDTH +: ACC_WIDTH] = c_wire[ROWS][j]; // Bottom C output
        end

        // Instantiate PEs
        for (i = 0; i < ROWS; i = i + 1) begin : row_gen
            for (j = 0; j < COLS; j = j + 1) begin : col_gen
                pe2 #(.WIDTH(WIDTH), .ACC_WIDTH(ACC_WIDTH), .MUL_LATENCY(MUL_LATENCY), .ADD_LATENCY(ADD_LATENCY)) pe (
                    .clk(clk), .rst_n(rst_n),
                    .b_load(b_load), .b_update(b_update_chain[i][j]),
                    .a_in(a_wire[i][j]), .b_in(b_wire[i][j]), .c_in(c_wire[i][j]),
                    .a_out(a_wire[i][j+1]), .b_out(b_wire[i+1][j]), .c_out(c_wire[i+1][j]),
                    .b_update_out(b_update_chain[i][j+1])
                );
            end
        end
    endgenerate

endmodule