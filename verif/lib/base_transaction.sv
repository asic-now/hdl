// verif/lib/base_transaction.sv
// Generic, parameterized base class for all transactions.
// It is parameterized by the number of inputs (NUM_INPUTS) and data INPUT_WIDTH and OUTPUT_WIDTH.

`include "uvm_macros.svh"
import uvm_pkg::*;

virtual class base_transaction #(
    int NUM_INPUTS = 1,
    int INPUT_WIDTH = 16,
    int OUTPUT_WIDTH = 16
) extends uvm_sequence_item;

    // --- Data Fields ---
    rand logic [INPUT_WIDTH-1:0] inputs[]; // Dynamic array
    logic [OUTPUT_WIDTH-1:0] result;

    // Constructor
    function new(string name = "base_transaction");
        super.new(name);
        // Allocate the dynamic array
        inputs = new[NUM_INPUTS];
    endfunction

    virtual function string convert2string();
        string s;
        s = $sformatf("[%s]: inputs[", get_name());
        foreach(inputs[i]) begin
            s = {s, $sformatf("%s0x%h", (i > 0) ? ", " : "", inputs[i])};
        end
        s = {s, $sformatf("] -> result=0x%h", result)};
        return s;
    endfunction

    // Compares this transaction (DUT) with a golden transaction, generates a
    // formatted log message, and indicates if they match.
    virtual function string compare(input uvm_sequence_item golden_trans_item, output bit is_match);
        base_transaction #(NUM_INPUTS, INPUT_WIDTH, OUTPUT_WIDTH) golden_trans;
        if (!$cast(golden_trans, golden_trans_item)) begin
            `uvm_fatal("CAST_FAIL", "Failed to cast golden transaction in base_transaction::compare")
            is_match = 0;
            return "FATAL: Cast failed in compare()";
        end

        is_match = (this.result == golden_trans.result);
        if (is_match) begin
            return this.convert2string();
        end else begin
            string s;
            s = $sformatf("[%s]: inputs[", get_name());
            foreach(inputs[i]) begin
                s = {s, $sformatf("%s0x%h", (i > 0) ? ", " : "", inputs[i])};
            end
            s = {s, $sformatf("] -> DUT=0x%h, MODEL=0x%h", result, golden_trans.result)};
            return s;
        end
    endfunction

endclass
