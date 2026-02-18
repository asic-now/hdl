module systolic_tb_top;

    parameter ROWS = 2;
    parameter COLS = 2;
    parameter WIDTH = 4;
    parameter ACC_WIDTH = 9;
    parameter MUL_LATENCY = 0;
    parameter ADD_LATENCY = 1;

    reg clk;
    reg rst_n;
    reg [ROWS*ROWS*WIDTH-1:0] a;
    reg [ROWS*COLS*WIDTH-1:0] b;
    reg in_valid;
    wire [ROWS*COLS*ACC_WIDTH-1:0] c;
    wire out_valid;
    wire in_ready;

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
        .a(a),
        .b(b),
        .in_valid(in_valid),
        .in_ready(in_ready),
        .c(c),
        .out_valid(out_valid)
    );

    // Helper to set A matrix elements
    function void set_a(int r, int c_idx, int val);
        a[(r*ROWS + c_idx)*WIDTH +: WIDTH] = val;
    endfunction

    // Helper to set B matrix elements
    function void set_b(int r, int c_idx, int val);
        b[(r*COLS + c_idx)*WIDTH +: WIDTH] = val;
    endfunction

    // Helper to get C matrix elements
    function int get_c(int r, int c_idx);
        return c[(r*COLS + c_idx)*ACC_WIDTH +: ACC_WIDTH];
    endfunction

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Test Sequence
    initial begin
        $dumpfile("systolic_tb_top.vcd");
        $dumpvars(0, systolic_tb_top);

        rst_n = 0;
        in_valid = 0;
        a = 0;
        b = 0;

        #20;
        rst_n = 1;
        #10;

        // --- Test Case 1: Identity Matrix x Identity Matrix ---
        // A = I, B = I -> C = I
        $display("Starting Test 1: I x I");
        set_a(0,0,1); set_a(0,1,0); set_a(1,0,0); set_a(1,1,1);
        set_b(0,0,1); set_b(0,1,0); set_b(1,0,0); set_b(1,1,1);
        in_valid = 1;
        #10;
        in_valid = 0;

        // Wait for output
        wait(out_valid);
        #1;
        $display("Output 1: %d %d / %d %d", get_c(0,0), get_c(0,1), get_c(1,0), get_c(1,1));
        if (get_c(0,0) == 1 && get_c(0,1) == 0 && get_c(1,0) == 0 && get_c(1,1) == 1)
            $display("Test 1 PASS");
        else
            $display("Test 1 FAIL");

        #20;

        // --- Test Case 2: Consecutive Multiplications ---
        // Op 1: A = [[1, 2], [3, 4]], B = [[1, 0], [0, 1]] (Identity) -> C = A
        // Op 2: A = [[1, 1], [1, 1]], B = [[2, 2], [2, 2]] -> C = [[4, 4], [4, 4]]
        
        $display("Starting Test 2: Consecutive Ops");
        
        // Drive Op 1
        wait(in_ready);
        set_a(0,0,1); set_a(0,1,2); set_a(1,0,3); set_a(1,1,4);
        set_b(0,0,1); set_b(0,1,0); set_b(1,0,0); set_b(1,1,1);
        in_valid = 1;
        #10;
        
        // Drive Op 2 immediately (back-to-back)
        // The controller should buffer this
        wait(in_ready);
        set_a(0,0,1); set_a(0,1,1); set_a(1,0,1); set_a(1,1,1);
        set_b(0,0,2); set_b(0,1,2); set_b(1,0,2); set_b(1,1,2);
        in_valid = 1;
        #10;
        in_valid = 0;

        // Wait for Op 1 Output
        wait(out_valid);
        #1;
        $display("Output Op 1: %d %d / %d %d", get_c(0,0), get_c(0,1), get_c(1,0), get_c(1,1));
        if (get_c(0,0) == 1 && get_c(0,1) == 2 && get_c(1,0) == 3 && get_c(1,1) == 4)
            $display("Op 1 PASS");
        else
            $display("Op 1 FAIL");
        
        wait(!out_valid);
        
        // Wait for Op 2 Output
        wait(out_valid);
        #1;
        $display("Output Op 2: %d %d / %d %d", get_c(0,0), get_c(0,1), get_c(1,0), get_c(1,1));
        if (get_c(0,0) == 4 && get_c(0,1) == 4 && get_c(1,0) == 4 && get_c(1,1) == 4)
            $display("Op 2 PASS");
        else
            $display("Op 2 FAIL");

        #50;
        $finish;
    end
endmodule