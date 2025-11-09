// rtl/verilog/lib/rss.v
// right_shift_sticky_bit

module rss #(
    parameter WIDTH = 8,
    parameter SHIFT_WIDTH = $clog2(WIDTH)
) (
    input  wire [WIDTH-1:0]  data_in,
    input  wire [SHIFT_WIDTH-1:0] shift_amount,
    output wire [WIDTH-1:0]  data_out
);

// Perform logical right shift
    wire [WIDTH-1:0] shifted = data_in >> shift_amount;
    // wire [WIDTH-1:0] mask = (shift_amount >= WIDTH) ? {WIDTH{1'b1}} : (({{(WIDTH-1){1'b0}},{1'b1}} << shift_amount) - 1);
    // Generate mask of 1's the width of shift_amount bits. Synthesizable.
    reg [WIDTH-1:0] mask;
    integer i;
    always @(*) begin
        mask = {WIDTH{1'b0}};
        for (i = 0; i < WIDTH; i = i + 1) begin
            mask[i] = (i < shift_amount) ? 1'b1 : 1'b0;
        end
    end

    // The bits shifted out are data_in[shift_amount-1:0] — OR all those bits for sticky calculation
    // wire sticky = (shift_amount >= WIDTH) ? |data_in : |data_in[shift_amount-1:0]; // Method 1a. Some tools may complain and choke on non-constant shift_amount
    // wire sticky = |data_in[((shift_amount >= WIDTH) ? WIDTH : shift_amount)-1:0]; // Method 1b. Some tools may complain and choke on non-constant shift_amount
    wire sticky = |(data_in & mask); // Method 2. This method is safe for large shift_amount
    
    // Set LSB of data_out to OR of shifted LSB and sticky
    assign data_out = {shifted[WIDTH-1:1], shifted[0] | sticky};

endmodule
