// verif/lib/fp_transaction.sv
// Transaction class for floating-point operations.
// Extends the base_transaction to add canonical comparison.

`include "uvm_macros.svh"
import uvm_pkg::*;
import fp_utils_pkg::*;

class fp_transaction #(
    int NUM_INPUTS = 2,
    int INPUT_WIDTH = 16,
    int OUTPUT_WIDTH = 16
) extends base_transaction #(NUM_INPUTS, INPUT_WIDTH, OUTPUT_WIDTH);

    `uvm_object_param_utils(fp_transaction #(INPUT_WIDTH, NUM_INPUTS))

    function new(string name = "fp_transaction");
        super.new(name);
    endfunction

    // Override the compare function to handle FP-specific canonicalization.
    // It now returns a fully formatted log message for both PASS and FAIL cases.
    virtual function string compare(input uvm_sequence_item golden_trans_item, output bit is_match);
        fp_transaction #(NUM_INPUTS, INPUT_WIDTH, OUTPUT_WIDTH) golden_trans;
        logic [OUTPUT_WIDTH-1:0] dut_canonical, golden_canonical;
        string s;

        if (!$cast(golden_trans, golden_trans_item)) begin
            `uvm_fatal("CAST_FAIL", "Failed to cast golden transaction in fp_transaction::compare")
            is_match = 0;
            return "FATAL: Cast failed in fp_transaction::compare()";
        end

        dut_canonical    = fp_utils::fp16_canonicalize(result); // TODO: (when needed) Convert to generic with OUTPUT_WIDTH param.
        golden_canonical = fp_utils::fp16_canonicalize(golden_trans.result);
        is_match = (dut_canonical == golden_canonical);

        // Format inputs
        s = $sformatf("[%s]: inputs[", get_name());
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
