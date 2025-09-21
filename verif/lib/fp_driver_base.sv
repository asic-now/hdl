// verif/lib/fp_driver_base.sv
//
// Generic, parameterized base class for a driver. It contains a pure
// virtual task 'drive_transfer' that MUST be implemented by a child class.

`include "uvm_macros.svh"
import uvm_pkg::*;

virtual class fp_driver_base #(
    type T_TRANS = uvm_sequence_item,
    type T_VIF
) extends uvm_driver #(T_TRANS);

    T_VIF vif;
    // This port will broadcast every transaction the driver sends.
    uvm_analysis_port #(T_TRANS) ap;
    int unsigned epsilon_delay = 1; // Default to a 1-timeunit delay

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(T_VIF)::get(this, "", "dut_vif", vif))
            `uvm_fatal("NOVIF", "Could not get virtual interface handle")
    endfunction

    virtual task run_phase(uvm_phase phase);
        @(posedge vif.rst_n);
        forever begin
            @(posedge vif.clk);
            seq_item_port.get_next_item(req);
            pre_drive();
            drive_transfer(req);
            ap.write(req); // Broadcast the driven transaction
            seq_item_port.item_done();
        end
    endtask

    // This task provides the #epsilon delay. It can be overridden in child
    // classes if a different delay is needed.
    virtual task pre_drive();
        #epsilon_delay;
    endtask

    // This is a placeholder task that MUST be implemented by the DUT-specific driver
    pure virtual task drive_transfer(T_TRANS trans);

endclass
