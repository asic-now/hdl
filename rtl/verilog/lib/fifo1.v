module fifo1 #(
    parameter WIDTH = 8,
    parameter DEPTH = 4
) (
    input  wire             clk,
    input  wire             rst_n,
    input  wire             push,
    input  wire             pop,
    input  wire [WIDTH-1:0] d_in,
    output wire [WIDTH-1:0] d_out,
    output wire             full,
    output wire             empty
);

    reg [WIDTH-1:0] mem [DEPTH-1:0];
    reg [$clog2(DEPTH)-1:0] wr_ptr;
    reg [$clog2(DEPTH)-1:0] rd_ptr;
    reg [$clog2(DEPTH+1)-1:0] count;

    assign full = (count == DEPTH);
    assign empty = (count == 0);
    assign d_out = mem[rd_ptr];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= 0;
            rd_ptr <= 0;
            count <= 0;
        end else begin
            if (push && !full) begin
                mem[wr_ptr] <= d_in;
                wr_ptr <= (wr_ptr == DEPTH-1) ? 0 : wr_ptr + 1;
            end
            
            if (pop && !empty) begin
                rd_ptr <= (rd_ptr == DEPTH-1) ? 0 : rd_ptr + 1;
            end

            if (push && !full && !(pop && !empty))
                count <= count + 1;
            else if (!(push && !full) && (pop && !empty))
                count <= count - 1;
        end
    end

endmodule