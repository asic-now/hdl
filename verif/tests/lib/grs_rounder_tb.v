// verif/tests/lib/grs_rounder_tb.vh

// `timescale 1ns / 1ps

`include "grs_round.vh"  // \`RNE, etc.

module grs_rounder_tb;

    // --- Parameters ---
    localparam INPUT_W  = 8;
    localparam OUTPUT_W = 4;
    localparam DESC_W   = 8 * 40; // 40 characters for description

    // --- Testbench Signals ---
    reg  [INPUT_W-1:0]  tb_value_in;
    reg                 tb_sign_in;
    reg  [2:0]          tb_mode;
    reg  [OUTPUT_W-1:0] tb_value_out;
    reg                 tb_overflow_out;

    // --- Instantiate the DUT ---
    grs_rounder #(
        .INPUT_WIDTH(INPUT_W),
        .OUTPUT_WIDTH(OUTPUT_W)
    ) dut (
        .value_in(tb_value_in),
        .sign_in(tb_sign_in),
        .mode(tb_mode),
        .value_out(tb_value_out),
        .overflow_out(tb_overflow_out)
    );

    // --- Test Task ---
    task test_case(
        input [INPUT_W-1:0]  val,
        input                sign,
        input [2:0]          mode,
        input [OUTPUT_W-1:0] expected_val,
        input                expected_overflow,
        input [DESC_W-1:0]   test_name
    );
        tb_value_in = val;
        tb_sign_in  = sign;
        tb_mode     = mode;
        #10; // Allow combinational logic to settle
        if (tb_value_out === expected_val && tb_overflow_out === expected_overflow) begin
            $display("PASS: %s (val: %b, sign: %b, out: %b, ovf: %b)", test_name, val, sign, tb_value_out, tb_overflow_out);
        end else begin
            $display("FAIL: %s (val: %b, sign: %b, out: %b, ovf: %b, exp_out: %b, exp_ovf: %b)", 
                     test_name, val, sign, tb_value_out, tb_overflow_out, expected_val, expected_overflow);
        end
    endtask

    // --- Test Sequence ---
    initial begin
        $display("--- Starting GRS Rounder Testbench ---");
        $display("--- INPUT_WIDTH=%0d, OUTPUT_WIDTH=%0d ---", INPUT_W, OUTPUT_W);

        // --- Test Cases for RNE (Ties to Even) ---
        test_case(8'b0010_0110, 1'b0, `RNE, 4'b0010, 1'b0, "RNE: Less than half, truncate");
        test_case(8'b0010_1000, 1'b0, `RNE, 4'b0010, 1'b0, "RNE: Tie to even (LSB=0)");
        test_case(8'b0011_1000, 1'b0, `RNE, 4'b0100, 1'b0, "RNE: Tie to even (LSB=1)");
        test_case(8'b0011_1001, 1'b0, `RNE, 4'b0100, 1'b0, "RNE: Greater than half");
        test_case(8'b1111_1111, 1'b0, `RNE, 4'b0000, 1'b1, "RNE: Overflow case");

        // --- Test Cases for RTZ (Towards Zero) ---
        test_case(8'b1001_1111, 1'b0, `RTZ, 4'b1001, 1'b0, "RTZ: Always truncate");

        // --- Test Cases for RPI (Towards +Inf) ---
        test_case(8'b0101_0001, 1'b0, `RPI, 4'b0110, 1'b0, "RPI: Positive, inexact -> round up");
        test_case(8'b0101_0001, 1'b1, `RPI, 4'b0101, 1'b0, "RPI: Negative, inexact -> truncate");
        test_case(8'b0101_0100, 1'b0, `RPI, 4'b0110, 1'b0, "RPI: Positive, inexact (r=1) -> round up");
        test_case(8'b0101_0000, 1'b0, `RPI, 4'b0101, 1'b0, "RPI: Positive, exact -> no change");

        // --- Test Cases for RNI (Towards -Inf) ---
        test_case(8'b0101_0001, 1'b0, `RNI, 4'b0101, 1'b0, "RNI: Positive, inexact -> truncate");
        test_case(8'b0101_0001, 1'b1, `RNI, 4'b0110, 1'b0, "RNI: Negative, inexact -> round up");
        test_case(8'b0101_0100, 1'b1, `RNI, 4'b0110, 1'b0, "RNI: Negative, inexact (r=1) -> round up");

        // --- Test Cases for RNA (Ties Away from Zero) ---
        test_case(8'b0010_1000, 1'b0, `RNA, 4'b0011, 1'b0, "RNA: Tie away from zero");
        test_case(8'b0011_1000, 1'b0, `RNA, 4'b0100, 1'b0, "RNA: Tie away from zero");
        test_case(8'b1111_1000, 1'b0, `RNA, 4'b0000, 1'b1, "RNA: Overflow case");

        #10;
        $finish;
    end

endmodule
