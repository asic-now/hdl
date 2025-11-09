// verif/tests/lib/fas_vec_tb.vh

// `timescale 1ns / 1ps

module fas_vec_tb;

    // --- Parameters ---
    localparam WIDTH = 5;

    // --- Testbench Signals ---
    reg  [WIDTH-1:0] tb_a;
    reg  [WIDTH-1:0] tb_b;
    reg              tb_cin;
    reg              tb_add_nsub;  // 0: add, 1: subtract

    wire [WIDTH-1:0] tb_z;
    wire             tb_cout;

    // --- Instantiate DUT ---
    fas_vec #(.WIDTH(WIDTH)) dut (
        .a(tb_a),
        .b(tb_b),
        .cin(tb_cin),
        .add_nsub(tb_add_nsub),
        .z(tb_z),
        .cout(tb_cout)
    );

    // --- Task to perform a single test case ---
    task test_case(
        input [WIDTH-1:0] a,
        input [WIDTH-1:0] b,
        input             cin,
        input             add_nsub,
        input [WIDTH-1:0] expected_z,
        input             expected_cout,
        input [32*8-1:0]  test_name
    );
    begin
        tb_a = a;
        tb_b = b;
        tb_cin = cin;
        tb_add_nsub = add_nsub;
        #10; // Wait for combinational logic to settle

        if (tb_z === expected_z && tb_cout === expected_cout)
            $display("PASS: %s a=%b b=%b cin=%b mode=%b => z=%b cout=%b",
                     test_name, a, b, cin, add_nsub, tb_z, tb_cout);
        else
            $display("FAIL: %s a=%b b=%b cin=%b mode=%b => z=%b cout=%b (expected z=%b cout=%b)",
                     test_name, a, b, cin, add_nsub, tb_z, tb_cout, expected_z, expected_cout);
    end
    endtask

    // --- Test sequence ---
    initial begin
        $display("--- Starting fas_vec testbench ---");

        //               a,        b, cin, add_nsub, exp_z, exp_cout, test_name
        //==========================================================================================

        // Test addition mode (add_nsub=0)
        test_case(5'b00001, 5'b00001, 1'b0, 1'b0, 5'b00010, 1'b0, "Add 1 + 1     no carry");
        test_case(5'b11111, 5'b00001, 1'b0, 1'b0, 5'b00000, 1'b1, "Add max + 1      carry");
        test_case(5'b10101, 5'b01010, 1'b0, 1'b0, 5'b11111, 1'b0, "Add 21 + 10   no carry");
        test_case(5'b10101, 5'b01010, 1'b1, 1'b0, 5'b00000, 1'b1, "Add 21 + 10 + 1  carry");
        test_case(5'b11111, 5'b11111, 1'b1, 1'b0, 5'b11110, 1'b1, "Add max + max    carry");

        // Test subtraction mode (add_nsub=1)
        test_case(5'b00000, 5'b00000, 1'b0, 1'b1, 5'b00000, 1'b0, "Sub zero - zero");
        test_case(5'b01010, 5'b00101, 1'b0, 1'b1, 5'b00101, 1'b0, "Sub 10 - 5        no borrow");
        test_case(5'b00101, 5'b01010, 1'b0, 1'b1, 5'b11011, 1'b1, "Sub 5 - 10           borrow");
        test_case(5'b11111, 5'b00001, 1'b0, 1'b1, 5'b11110, 1'b0, "Sub max - 1       no borrow");
        test_case(5'b00000, 5'b00000, 1'b1, 1'b1, 5'b11111, 1'b1, "Sub zero - zero - 1  borrow");
        test_case(5'b00101, 5'b01010, 1'b1, 1'b1, 5'b11010, 1'b1, "Sub 5 - 10 - 1       borrow");
        test_case(5'b11111, 5'b00001, 1'b1, 1'b1, 5'b11101, 1'b0, "Sub max - 1 - 1   no borrow");

        #10;
        $display("--- fas_vec testbench completed ---");
        $finish;
    end

endmodule
