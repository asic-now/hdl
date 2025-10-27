// verif/tests/fp_classify/fp_classify_agent.sv
// Parameterized UVM Agent for the fp_classify DUT.

`include "uvm_macros.svh"
import uvm_pkg::*;

class fp_classify_agent #(
    parameter int WIDTH = 16
) extends uvm_agent;

    `uvm_component_param_utils(fp_classify_agent #(WIDTH))

    fp_classify_driver #(WIDTH) driver;
    fp_classify_monitor #(WIDTH) monitor;
    uvm_sequencer #(fp_classify_transaction #(WIDTH)) seqr;

    // Synchronization FIFO between driver and monitor
    uvm_tlm_analysis_fifo #(fp_classify_transaction #(WIDTH)) fifo;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        fifo = new("fifo", this);
        monitor = fp_classify_monitor #(WIDTH)::type_id::create("monitor", this);

        if (get_is_active() == UVM_ACTIVE) begin
            driver = fp_classify_driver #(WIDTH)::type_id::create("driver", this);
            seqr = uvm_sequencer #(fp_classify_transaction #(WIDTH))::type_id::create("seqr", this);
        end
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        if (get_is_active() == UVM_ACTIVE) begin
            driver.seq_item_port.connect(seqr.seq_item_export);
            // Connect the driver's broadcast port to the FIFO's input
            driver.ap.connect(fifo.analysis_export);
        end
        // Connect the monitor's get_port to the FIFO's output
        monitor.get_port.connect(fifo.get_export);
    endfunction

endclass
