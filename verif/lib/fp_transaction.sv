// verif/lib/fp_transaction.sv
// Transaction class for floating-point operations.
// Extends the base_transaction to add canonical comparison.

`include "uvm_macros.svh"
import uvm_pkg::*;

`include "grs_round.vh"  // \`RNE, etc.

class fp_transaction #(
    int NUM_INPUTS = 2,
    int INPUT_WIDTH = 16,
    int OUTPUT_WIDTH = 16
) extends base_transaction #(NUM_INPUTS, INPUT_WIDTH, OUTPUT_WIDTH);

    `uvm_object_param_utils(fp_transaction #(NUM_INPUTS, INPUT_WIDTH, OUTPUT_WIDTH))

    // Rounding modes matching grs_round.vh
    rand logic [2:0] rm;

    function new(string name = "fp_transaction");
        super.new(name);
    endfunction

    constraint rounding_mode_c {
        rm inside {`RNE, `RTZ, `RPI, `RNI, `RNA};
    }

    // Override the compare function to handle FP-specific canonicalization.
    // It now returns a fully formatted log message for both PASS and FAIL cases.
    virtual function string compare(input uvm_sequence_item golden_trans_item, output bit is_match);
        fp_transaction #(NUM_INPUTS, INPUT_WIDTH, OUTPUT_WIDTH) golden_trans;
        logic [OUTPUT_WIDTH-1:0] dut_canonical, golden_canonical;
        string s, rm_str;

        if (!$cast(golden_trans, golden_trans_item)) begin
            `uvm_fatal("CAST_FAIL", "Failed to cast golden transaction in fp_transaction::compare()")
            is_match = 0;
            return "FATAL: Cast failed in fp_transaction::compare()";
        end

        // Use parameterized canonicalize function.
        // This is type-safe and automatically adapts to the OUTPUT_WIDTH.
        dut_canonical    = fp_utils_t#(OUTPUT_WIDTH)::canonicalize(result);
        golden_canonical = fp_utils_t#(OUTPUT_WIDTH)::canonicalize(golden_trans.result);

        is_match = (dut_canonical == golden_canonical);

        // The rounding mode should be identical for both DUT and MODEL
        // If it's not, it indicates a testbench error or a mismatch in how
        // the mode is passed/interpreted.
        if (this.rm != golden_trans.rm) begin
            `uvm_error("ROUND_MODE_MISMATCH", $sformatf("Rounding mode mismatch: DUT=%0d, MODEL=%0d", this.rm, golden_trans.rm))
            is_match = 0; // Treat as a failure if rounding mode itself doesn't match
        end

        // Convert rm to string for better readability in logs
        case (this.rm)
            `RNE: rm_str = "RNE";
            `RTZ: rm_str = "RTZ";
            `RPI: rm_str = "RPI";
            `RNI: rm_str = "RNI";
            `RNA: rm_str = "RNA";
            default: rm_str = $sformatf("UNKNOWN(%0d)", this.rm);
        endcase

        // Format inputs
        s = $sformatf("[%s]: RM=%s, inputs[", get_name(), rm_str);
        foreach(inputs[i]) begin
            s = {s, $sformatf("%s0x%h", (i > 0) ? ", " : "", inputs[i])};
        end

        // Add result or comparison depending on is_match
        if (is_match) begin
            s = {s, $sformatf("] -> result=0x%h | Canonical: result=0x%h", result, dut_canonical)};
        end else begin
            s = {s, $sformatf("] -> DUT=0x%h, MODEL=0x%h", result, golden_trans.result)};
            s = {s, $sformatf(" | Canonical: DUT=0x%h, MODEL=0x%h", dut_canonical, golden_canonical)};
        end
        return s;
    endfunction
endclass
