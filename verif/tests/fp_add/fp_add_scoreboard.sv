// verif/tests/fp_add/fp_add_scoreboard.sv
// Parameterized UVM scoreboard for the fp_add DUT.

class fp_add_scoreboard #(
    parameter int WIDTH = 16
) extends uvm_scoreboard;

    `uvm_component_param_utils(fp_add_scoreboard #(WIDTH))

    // Ports to receive transactions from the model (expected) and monitor (actual)
    uvm_analysis_imp #(fp_transaction2 #(WIDTH), fp_add_scoreboard #(WIDTH)) expected_export;
    uvm_analysis_imp #(fp_transaction2 #(WIDTH), fp_add_scoreboard #(WIDTH)) actual_export;

    // FIFOs to store incoming transactions
    uvm_tlm_analysis_fifo #(fp_transaction2 #(WIDTH)) expected_fifo;
    uvm_tlm_analysis_fifo #(fp_transaction2 #(WIDTH)) actual_fifo;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        expected_export = new("expected_export", this);
        actual_export = new("actual_export", this);
        expected_fifo = new("expected_fifo", this);
        actual_fifo = new("actual_fifo", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        expected_export.connect(expected_fifo.analysis_export);
        actual_export.connect(actual_fifo.analysis_export);
    endfunction

    task run_phase(uvm_phase phase);
        fp_transaction2 #(WIDTH) expected_trans, actual_trans;
        forever begin
            // Wait for both an expected and an actual transaction to arrive
            expected_fifo.get(expected_trans);
            actual_fifo.get(actual_trans);

            // Compare the results
            if (!expected_trans.compare(actual_trans)) begin
                `uvm_error("SCOREBOARD", $sformatf("Transaction mismatch!\n\tExpected: %s\n\tActual:   %s",
                    expected_trans.sprint(), actual_trans.sprint()))
            end else begin
                `uvm_info("SCOREBOARD", $sformatf("Transaction match: a=0x%h, b=0x%h -> result=0x%h",
                    actual_trans.a, actual_trans.b, actual_trans.result), UVM_HIGH)
            end
        end
    endtask

    // Override the default compare to only check the result field
    function bit compare_transactions(fp_transaction2 #(WIDTH) exp, fp_transaction2 #(WIDTH) act);
        return exp.result == act.result;
    endfunction

endclass