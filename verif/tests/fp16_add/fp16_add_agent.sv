// verif/tests/fp16_add/fp16_add_agent.sv
// UVM Agent for the fp16_add DUT.

`include "uvm_macros.svh"
import uvm_pkg::*;

class fp16_add_agent extends uvm_agent;
    `uvm_component_utils(fp16_add_agent)

    fp16_add_driver driver;
    fp16_add_monitor monitor;
    uvm_sequencer #(fp16_transaction2) seqr;

    // The analysis FIFO that synchronizes the driver and monitor
    uvm_tlm_analysis_fifo #(fp16_transaction2) fifo;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        fifo = new("fifo", this);
        monitor = fp16_add_monitor::type_id::create("monitor", this);
        if(get_is_active() == UVM_ACTIVE) begin
            driver = fp16_add_driver::type_id::create("driver", this);
            seqr = uvm_sequencer #(fp16_transaction2)::type_id::create("seqr", this);
        end
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        if(get_is_active() == UVM_ACTIVE) begin
            driver.seq_item_port.connect(seqr.seq_item_export);
            // Connect the driver's broadcast port to the FIFO's input
            driver.ap.connect(fifo.analysis_export);
        end
        // Connect the monitor's get_port to the FIFO's output
        monitor.get_port.connect(fifo.get_export);
    endfunction

endclass
