// verif/lib/base_scoreboard.sv
// Generic, reusable scoreboard for comparing transactions.

`include "uvm_macros.svh"
import uvm_pkg::*;

class base_scoreboard #(
    type T_TRANS = uvm_sequence_item,
    type T_MODEL = uvm_object
) extends uvm_scoreboard;
    `uvm_component_param_utils(base_scoreboard #(T_TRANS, T_MODEL))

    uvm_analysis_imp #(T_TRANS, base_scoreboard #(T_TRANS, T_MODEL)) ap;
    T_MODEL model;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(T_MODEL)::get(this, "*", "model", model))
            `uvm_fatal("NO_MODEL", "Could not get model handle in scoreboard")
    endfunction

    virtual function void write(T_TRANS dut_trans);
        T_TRANS golden_trans;
        bit is_match;
        string log_message;

        model.predict(dut_trans, golden_trans);

        // Delegate comparison to the transaction object itself.
        log_message = dut_trans.compare(golden_trans, is_match);

        if (is_match)
            `uvm_info("SCOREBOARD", $sformatf("PASS %s", log_message), UVM_LOW)
        else
            `uvm_error("SCOREBOARD", $sformatf("FAIL %s", log_message))
    endfunction
endclass