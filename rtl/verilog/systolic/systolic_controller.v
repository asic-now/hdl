/*
 * Systolic Array Controller
 * Handles sequencing of weight loading, input skewing, and output collection.
 */
module systolic_controller #(
    parameter ROWS = 2,
    parameter COLS = 2,
    parameter WIDTH = 4,
    parameter ACC_WIDTH = 9,
    parameter MUL_LATENCY = 0,
    parameter ADD_LATENCY = 1
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       in_valid,
    output wire       in_ready,
    // Inputs A
    input  wire [ROWS*ROWS*WIDTH-1:0] a_flat,
    // Inputs B
    input  wire [ROWS*COLS*WIDTH-1:0] b_flat,
    // Array Interface
    output reg        b_load,
    output reg        b_update,
    output reg  [ROWS*WIDTH-1:0] a_row_flat,
    output reg  [COLS*WIDTH-1:0] b_col_flat,
    input  wire [COLS*ACC_WIDTH-1:0] c_col_flat,
    input  wire       b_update_done,
    // System Outputs
    output reg  [ROWS*COLS*ACC_WIDTH-1:0] c_flat,
    output reg        out_valid
);

    localparam ALU_LATENCY = MUL_LATENCY + ADD_LATENCY;
    localparam FIFO_DEPTH = 4;

    //-------------------------------------------------------------------------
    // Input FIFO (Stores A and B matrices)
    //-------------------------------------------------------------------------
    wire [ROWS*ROWS*WIDTH + ROWS*COLS*WIDTH - 1 : 0] fifo_in;
    wire [ROWS*ROWS*WIDTH + ROWS*COLS*WIDTH - 1 : 0] fifo_out;
    wire fifo_full, fifo_empty;
    wire fifo_push, fifo_pop;

    assign fifo_in = {a_flat, b_flat};
    assign fifo_push = in_valid;
    assign in_ready = !fifo_full;

    fifo1 #(
        .WIDTH(ROWS*ROWS*WIDTH + ROWS*COLS*WIDTH),
        .DEPTH(FIFO_DEPTH)
    ) input_fifo (
        .clk(clk), .rst_n(rst_n),
        .push(fifo_push), .pop(fifo_pop),
        .d_in(fifo_in), .d_out(fifo_out), // fifo_out is valid when !empty
        .full(fifo_full), .empty(fifo_empty)
    );

    //-------------------------------------------------------------------------
    // B Loading Logic
    //-------------------------------------------------------------------------
    localparam S_IDLE   = 3'd0;
    localparam S_LOAD   = 3'd1;
    localparam S_WAIT_A = 3'd2; // Wait for A streamer to be free
    localparam S_UPDATE = 3'd3;
    localparam S_WAIT   = 3'd4;

    reg [2:0] state;
    reg start_job;
    reg [$clog2(ROWS):0] load_cnt;
    reg [ROWS*ROWS*WIDTH-1:0] current_a;
    
    // Unpack B head for loading
    wire [ROWS*ROWS*WIDTH-1:0] a_head;
    wire [ROWS*COLS*WIDTH-1:0] b_head;
    assign {a_head, b_head} = fifo_out;

    wire [WIDTH-1:0] b_head_unpacked [ROWS-1:0][COLS-1:0];
    
    genvar r, c_idx;
    generate
        for (r=0; r<ROWS; r=r+1) begin : b_unpack_row
            for (c_idx=0; c_idx<COLS; c_idx=c_idx+1) begin : b_unpack_col
                assign b_head_unpacked[r][c_idx] = b_head[(r*COLS + c_idx)*WIDTH +: WIDTH];
            end
        end
    endgenerate

    // FIFO Pop Logic: Pop at the end of loading phase
    assign fifo_pop = (state == S_LOAD && load_cnt == ROWS - 1);

    // Forward declaration for A & C status
    reg a_active;
    reg c_active;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            load_cnt <= 0;
            b_load <= 0;
            b_update <= 0;
            current_a <= 0;
            start_job <= 0;
        end else begin
            // Default assignments
            b_load <= 0;
            b_update <= 0;
            start_job <= 0;

            case (state)
                S_IDLE: begin
                    if (!fifo_empty) begin
                        state <= S_LOAD;
                        load_cnt <= 0;
                        b_load <= 1;
                        current_a <= a_head; // Latch A for the upcoming job
                    end
                end

                S_LOAD: begin
                    b_load <= 1;
                    if (load_cnt == ROWS - 1) begin
                        b_load <= 0;
                        if (!a_active) begin
                            state <= S_UPDATE;
                            b_update <= 1; // Pulse update next cycle
                            start_job <= 1;
                        end else begin
                            state <= S_WAIT_A;
                        end
                    end else begin
                        load_cnt <= load_cnt + 1;
                    end
                end

                S_WAIT_A: begin
                    if (!a_active) begin
                        state <= S_UPDATE;
                        b_update <= 1; // Pulse update next cycle
                        start_job <= 1;
                    end
                end

                S_UPDATE: begin
                    // b_update is high this cycle.
                    state <= S_WAIT;
                end

                S_WAIT: begin
                    if (b_update_done) begin
                        if (!fifo_empty) begin
                            state <= S_LOAD;
                            load_cnt <= 0;
                            b_load <= 1;
                            current_a <= a_head; // Latch next A
                        end else begin
                            state <= S_IDLE;
                        end
                    end
                end
            endcase
        end
    end

    // Drive b_col_flat during loading
    // We feed rows of B into the top of the array.
    // To place Row R at the correct position, it must enter at cycle (ROWS-1)-R relative to start.
    integer j;
    always @(*) begin
        b_col_flat = 0;
        if (state == S_LOAD) begin
            if (load_cnt < ROWS) begin
                for (j=0; j<COLS; j=j+1) begin
                    b_col_flat[j*WIDTH +: WIDTH] = b_head_unpacked[ROWS - 1 - load_cnt][j];
                end
            end
        end
    end

    //-------------------------------------------------------------------------
    // A Streaming Logic (A FSM)
    //-------------------------------------------------------------------------
    // Streams A matrix into the array with appropriate skew.
    
    reg [7:0] a_timer;
    reg [ROWS*ROWS*WIDTH-1:0] active_a;
    integer r_idx;
    reg [WIDTH-1:0] a_val;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_active <= 0;
            a_timer <= 0;
            active_a <= 0;
        end else begin
            if (start_job) begin
                a_active <= 1;
                a_timer <= 0;
                active_a <= current_a;
            end else if (a_active) begin
                a_timer <= a_timer + 1;
                // Stop when last row has finished streaming
                // Last row (ROWS-1) starts at (ROWS-1)*ADD_LATENCY and lasts ROWS cycles
                if (a_timer == (ROWS-1)*ADD_LATENCY + ROWS - 1) begin
                    a_active <= 0;
                end
            end
        end
    end

    always @(*) begin
        a_row_flat = 0;
        if (a_active) begin
            for (r_idx=0; r_idx<ROWS; r_idx=r_idx+1) begin
                a_val = 0;
                // Row r starts at r*ADD_LATENCY
                if (a_timer >= r_idx*ADD_LATENCY && a_timer < r_idx*ADD_LATENCY + ROWS) begin
                    // Calculate column index of A to send
                    // We need to feed Column r_idx of A into Row r_idx of Array to compute C = A * B.
                    // So we need A[t][r_idx] where t is the sequence index (time).
                    // active_a is flattened row-major: A[row][col] is at (row*ROWS + col).
                    // Index = (time_offset * ROWS + r_idx).
                    a_val = active_a[((a_timer - r_idx*ADD_LATENCY)*ROWS + r_idx) * WIDTH +: WIDTH];
                end
                a_row_flat[r_idx*WIDTH +: WIDTH] = a_val;
            end
        end
    end

    //-------------------------------------------------------------------------
    // C Collection Logic (C FSM)
    //-------------------------------------------------------------------------
    // Collects C matrix from the array.
    // Triggered by start_job delayed by latency of the array.

    wire start_c_collection;
    localparam C_START_DELAY = ROWS*ADD_LATENCY + MUL_LATENCY;
    
    // Delay line for start signal
    if (C_START_DELAY > 0) begin : c_delay_gen
        reg [C_START_DELAY-1:0] c_start_sr;
        always @(posedge clk or negedge rst_n) begin
            if (!rst_n) c_start_sr <= 0;
            else begin
                if (C_START_DELAY == 1)
                    c_start_sr <= start_job;
                else
                    c_start_sr <= {c_start_sr[C_START_DELAY-2:0], start_job};
            end
        end
        assign start_c_collection = c_start_sr[C_START_DELAY-1];
    end else begin : c_no_delay
        assign start_c_collection = start_job;
    end

    reg [7:0] c_timer;
    reg [ROWS*COLS*ACC_WIDTH-1:0] c_buffer;
    integer c_j;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            c_active <= 0;
            c_timer <= 0;
            c_buffer <= 0;
            out_valid <= 0;
            c_flat <= 0;
        end else begin
            out_valid <= 0;

            if (start_c_collection) begin
                c_active <= 1;
                c_timer <= 0;
            end

            if (c_active) begin
                c_timer <= c_timer + 1;
                
                // Capture C elements as they exit the array
                // C[r, c] is valid at c_timer = r + c (relative to start_c_collection)
                for (c_j=0; c_j<COLS; c_j=c_j+1) begin
                    // Check if current timer corresponds to a valid row for this column
                    if (c_timer >= c_j && (c_timer - c_j) < ROWS) begin
                        // r = c_timer - c_j
                        c_buffer[((c_timer - c_j)*COLS + c_j)*ACC_WIDTH +: ACC_WIDTH] 
                            <= c_col_flat[c_j*ACC_WIDTH +: ACC_WIDTH];
                    end
                end

                // Finish when last element (bottom-right) is collected
                if (c_timer == (ROWS-1) + (COLS-1) + 1) begin
                    c_active <= 0;
                    out_valid <= 1;
                    c_flat <= c_buffer;
                end
            end
        end
    end
 
endmodule