/*
 * Processing Element (PE2), with weight double-buffering
 * Performs MAC operation: cout = a * b + cin
 */
module pe2 #(
    parameter WIDTH = 4,
    parameter ACC_WIDTH = 9,
    parameter MUL_LATENCY = 0,
    parameter ADD_LATENCY = 1
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       b_load,   // Enable shifting in new weights to shadow register
    input  wire       b_update, // Update active weight from shadow register
    input  wire [WIDTH-1:0] a_in,     // Activation input (from left)
    input  wire [WIDTH-1:0] b_in,     // Weight input (from top)
    input  wire [ACC_WIDTH-1:0] c_in,     // Partial sum input (from top)
    output reg  [WIDTH-1:0] a_out,    // Activation output (to right)
    output reg  [WIDTH-1:0] b_out,    // Weight output (to bottom)
    output wire [ACC_WIDTH-1:0] c_out,    // Partial sum output (to bottom)
    output reg        b_update_out  // Forwarded update signal (to right)
);

    localparam ALU_LATENCY = MUL_LATENCY + ADD_LATENCY;

    reg [WIDTH-1:0] b_active;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_out    <= {WIDTH{1'b0}};
            b_out    <= {WIDTH{1'b0}};
            b_active <= {WIDTH{1'b0}};
            b_update_out <= 1'b0;
        end else begin
            // Forward activation to the right
            a_out <= a_in;

            // Weight Loading Logic (Double Buffering)
            if (b_load) begin
                b_out <= b_in;
            end

            // Weight Update Logic
            if (b_update) begin
                b_active <= b_out;
            end

            // Forward b_update to the right
            b_update_out <= b_update;
        end
    end


    // Multiplier Pipeline
    wire [2*WIDTH-1:0] mul_result;
    wire [2*WIDTH-1:0] mul_result_delayed;
    
    assign mul_result = a_in * b_active;

    generate
        if (MUL_LATENCY == 0) begin : no_mul_lat
            assign mul_result_delayed = mul_result;
        end else begin : mul_lat
            reg [2*WIDTH-1:0] mul_pipe [MUL_LATENCY-1:0];
            integer m;
            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    for (m=0; m<MUL_LATENCY; m=m+1) mul_pipe[m] <= {(2*WIDTH){1'b0}};
                end else begin
                    mul_pipe[0] <= mul_result;
                    for (m=1; m<MUL_LATENCY; m=m+1) mul_pipe[m] <= mul_pipe[m-1];
                end
            end
            assign mul_result_delayed = mul_pipe[MUL_LATENCY-1];
        end
    endgenerate

    // Adder Pipeline
    wire [ACC_WIDTH-1:0] add_result;
    assign add_result = mul_result_delayed + c_in;

    generate
        if (ADD_LATENCY == 0) begin : no_add_lat
            assign c_out = add_result;
        end else begin : add_lat
            reg [ACC_WIDTH-1:0] add_pipe [ADD_LATENCY-1:0];
            integer a;
            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    for (a=0; a<ADD_LATENCY; a=a+1) add_pipe[a] <= {ACC_WIDTH{1'b0}};
                end else begin
                    add_pipe[0] <= add_result;
                    for (a=1; a<ADD_LATENCY; a=a+1) add_pipe[a] <= add_pipe[a-1];
                end
            end
            assign c_out = add_pipe[ADD_LATENCY-1];
        end
    endgenerate

endmodule
