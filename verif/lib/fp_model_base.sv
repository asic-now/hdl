// fp_model_base.sv
// Provides a virtual base class for all reference models.

`include "uvm_macros.svh"
import uvm_pkg::*;

// Abstract class that defines the interface for a reference model.
virtual class fp_model_base #(type REQ = uvm_sequence_item) extends uvm_component;

    // The analysis port where the model receives transactions from the monitor
    uvm_analysis_export #(REQ) port;
    
    // The analysis port to send predicted transactions to the scoreboard
    uvm_analysis_port #(REQ) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        port = new("port", this);
        ap = new("ap", this);
    endfunction

    // Pure virtual function that MUST be implemented by child classes
    // to define the DUT-specific behavior.
    pure virtual function void calculate_golden(REQ tx);

    virtual task run_phase(uvm_phase phase);
        REQ tx;
        forever begin
            port.get(tx);
            calculate_golden(tx);
            ap.write(tx);
            `uvm_info("MODEL", $sformatf("Predicted: %s", tx.convert2string()), UVM_HIGH)
        end
    endtask

endclass
