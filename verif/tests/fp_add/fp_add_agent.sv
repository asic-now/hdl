// verif/tests/fp_add/fp_add_agent.sv
// Parameterized UVM agent for the fp_add DUT.

`include "uvm_macros.svh"
import uvm_pkg::*;

class fp_add_agent #(
    parameter int WIDTH = 16
) extends uvm_agent;

    `uvm_component_param_utils(fp_add_agent #(WIDTH))

    // Components
    fp_add_driver #(WIDTH) driver;
    fp_add_monitor #(WIDTH) monitor;
    uvm_sequencer #(fp_transaction2 #(WIDTH)) seqr;

    // Analysis port to broadcast monitored transactions
    // uvm_analysis_port #(fp_transaction2 #(WIDTH)) ap;

    // Synchronization FIFO between driver and monitor
    uvm_tlm_analysis_fifo #(fp_transaction2 #(WIDTH)) fifo;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        // ap = new("ap", this);
        fifo = new("fifo", this);
        monitor = fp_add_monitor #(WIDTH)::type_id::create("monitor", this);

        if (get_is_active() == UVM_ACTIVE) begin
            driver = fp_add_driver #(WIDTH)::type_id::create("driver", this);
            seqr = uvm_sequencer #(fp_transaction2 #(WIDTH))::type_id::create("seqr", this);
        end
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        if (get_is_active() == UVM_ACTIVE) begin
            driver.seq_item_port.connect(seqr.seq_item_export);
            // The driver writes the transaction it just drove to the sync FIFO
            driver.ap.connect(fifo.analysis_export);
        end
        // The monitor gets the driven transaction from the FIFO to know what to expect
        monitor.get_port.connect(fifo.get_export);
        // The monitor broadcasts the completed (with result) transaction to the environment
        // monitor.ap.connect(this.ap);
    endfunction

endclass
