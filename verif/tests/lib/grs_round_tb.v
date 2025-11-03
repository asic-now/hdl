// verif/tests/lib/grs_round_tb.vh

// `timescale 1ns / 1ps

`include "grs_round.vh"  // \`RNE, etc.

module grs_round_tb;

    // --- Parameters ---
    localparam INPUT_W  = 8;
    localparam OUTPUT_W = 4;
    localparam DESC_W   = 8 * 40; // 40 characters for description

    // --- Testbench Signals ---
    reg  [INPUT_W-1:0]  tb_value_in;
    reg                 tb_sign_in;
    reg  [2:0]          tb_mode;
    reg                 tb_increment;

    // --- Instantiate the DUT ---
    grs_round #(
        .INPUT_WIDTH(INPUT_W),
        .OUTPUT_WIDTH(OUTPUT_W)
    ) dut (
        .value_in(tb_value_in),
        .sign_in(tb_sign_in),
        .mode(tb_mode),
        .increment(tb_increment)
    );

    // --- Test Task ---
    task test_case(
        input [INPUT_W-1:0]  val,
        input                sign,
        input [2:0]          mode,
        input                expected_inc,
        input [DESC_W-1:0]   test_name
    );
        tb_value_in = val;
        tb_sign_in  = sign;
        tb_mode     = mode;
        #10; // Allow combinational logic to settle
        if (tb_increment === expected_inc) begin
            $display("PASS: %s (val: %b, sign: %b, inc: %b)", test_name, val, sign, tb_increment);
        end else begin
            $display("FAIL: %s (val: %b, sign: %b, inc: %b, exp_inc: %b)", 
                     test_name, val, sign, tb_increment, expected_inc);
        end
    endtask

    // --- Test Sequence ---
    initial begin
        $display("--- Starting GRS Round Decision Logic Testbench (New Interface) ---");

        // --- Test cases defined by value_in that produces specific GRS bits ---
        // value_in[3:0] are the truncated bits [g,r,s,...]
        // value_in[4] is the LSB
        
        // RNE (Round to Nearest, Ties to Even)
        test_case(8'b0010_0110, 0, `RNE, 0, "RNE: < 0.5");
        test_case(8'b0010_1000, 0, `RNE, 0, "RNE: Tie, LSB=0 (even)");
        test_case(8'b0011_1000, 0, `RNE, 1, "RNE: Tie, LSB=1 (odd)");
        test_case(8'b0010_1001, 0, `RNE, 1, "RNE: > 0.5 (sticky bit)");
        test_case(8'b0010_1100, 0, `RNE, 1, "RNE: > 0.5 (round bit)");

        // RTZ (Round Towards Zero)
        test_case(8'b1111_1111, 1, `RTZ, 0, "RTZ: Always 0");

        // RPI (Round Towards +Inf)
        test_case(8'b0101_0000, 0, `RPI, 0, "RPI: Pos, Exact");
        test_case(8'b0101_0001, 0, `RPI, 1, "RPI: Pos, Inexact");
        test_case(8'b0101_0100, 0, `RPI, 1, "RPI: Pos, Inexact (r=1)");
        test_case(8'b0101_0001, 1, `RPI, 0, "RPI: Neg, Inexact");

        // RNI (Round Towards -Inf)
        test_case(8'b0101_0000, 1, `RNI, 0, "RNI: Neg, Exact");
        test_case(8'b0101_0001, 1, `RNI, 1, "RNI: Neg, Inexact (s=1)");
        test_case(8'b0101_0100, 1, `RNI, 1, "RNI: Neg, Inexact (r=1)");
        test_case(8'b0101_0001, 0, `RNI, 0, "RNI: Pos, Inexact");

        // RNA (Round to Nearest, Ties Away from Zero)
        test_case(8'b0010_0111, 0, `RNA, 0, "RNA: < 0.5");
        test_case(8'b0010_1000, 0, `RNA, 1, "RNA: Tie (>= 0.5)");

        #10;
        $finish;
    end

endmodule
