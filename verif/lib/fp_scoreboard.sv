// fp_scoreboard.sv
// Generic scoreboard to compare actual and expected results.

`include "uvm_macros.svh"
import uvm_pkg::*;

class fp_scoreboard #(type REQ = fp_transaction_base) extends uvm_scoreboard;
    `uvm_component_utils(fp_scoreboard #(REQ))

    uvm_analysis_imp #(REQ, fp_scoreboard #(REQ)) actual_export;
    uvm_tlm_analysis_fifo #(REQ) expected_fifo;

    int match_count = 0;
    int mismatch_count = 0;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        actual_export = new("actual_export", this);
        expected_fifo = new("expected_fifo", this);
    endfunction

    // This write function is called when the monitor sends a transaction
    virtual function void write(REQ actual_tx);
        REQ expected_tx;

        if (!expected_fifo.try_get(expected_tx)) begin
            `uvm_fatal("SCBD", "Received actual result from DUT when no expected result was available.")
            return;
        end
        
        // Generic comparison logic
        if (actual_tx.result == expected_tx.golden_result) begin
            match_count++;
            `uvm_info("SCBD_MATCH", $sformatf("PASS: %s", actual_tx.convert2string()), UVM_MEDIUM)
        end else begin
            // Special check for NaN vs NaN, which should be a match
            logic [14:10] res_exp = actual_tx.result[14:10]; // Assuming FP16 for NaN check
            logic res_is_nan = (res_exp == 5'h1F && actual_tx.result[9:0] != 0);
            logic [14:10] gold_exp = expected_tx.golden_result[14:10];
            logic gold_is_nan = (gold_exp == 5'h1F && expected_tx.golden_result[9:0] != 0);

            if (res_is_nan && gold_is_nan) begin
                match_count++;
                `uvm_info("SCBD_MATCH", $sformatf("PASS (NaN): %s", actual_tx.convert2string()), UVM_MEDIUM)
            end else begin
                mismatch_count++;
                `uvm_error("SCBD_MISMATCH", $sformatf("FAIL:\n\tActual: %s\n\tExpect: %s", 
                    actual_tx.convert2string(), expected_tx.convert2string()))
            end
        end
    endfunction

    function void report_phase(uvm_phase phase);
        `uvm_info(get_type_name(), $sformatf("Scoreboard Report: %0d matches, %0d mismatches", match_count, mismatch_count), UVM_LOW)
    endfunction
endclass
