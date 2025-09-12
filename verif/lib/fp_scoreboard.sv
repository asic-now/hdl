// fp_scoreboard.sv
// Generic scoreboard for comparing transactions.

`include "uvm_macros.svh"
import uvm_pkg::*;

class fp_scoreboard #(
    type T_TRANS = uvm_sequence_item,
    type T_MODEL = uvm_object
) extends uvm_scoreboard;
    `uvm_component_utils(fp_scoreboard #(T_TRANS, T_MODEL))

    uvm_analysis_imp #(T_TRANS, fp_scoreboard #(T_TRANS, T_MODEL)) ap;
    T_MODEL model;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        // Get the handle to the reference model from the environment
        if(!uvm_config_db#(T_MODEL)::get(this, "*", "model", model))
            `uvm_fatal("NO_MODEL", "Could not get model handle in scoreboard")
    endfunction

    // The write task is called when the monitor broadcasts a transaction
    virtual function void write(T_TRANS dut_trans);
        T_TRANS golden_trans;

        // Call the model to predict the golden result
        model.predict(dut_trans, golden_trans);

        // Explicitly compare the DUT result with the model's prediction
        if (dut_trans.result == golden_trans.golden_result) begin
            `uvm_info("SCOREBOARD", $sformatf("Compare OK: a=0x%h, b=0x%h, result=0x%h", dut_trans.a, dut_trans.b, dut_trans.result), UVM_LOW)
        end else begin
            `uvm_error("SCOREBOARD", $sformatf("Compare FAIL:\n  DUT received:   a=0x%h, b=0x%h --> result=0x%h\n  MODEL predicted: a=0x%h, b=0x%h --> result=0x%h",
                dut_trans.a, dut_trans.b, dut_trans.result,
                golden_trans.a, golden_trans.b, golden_trans.golden_result))
        end
    endfunction

endclass
