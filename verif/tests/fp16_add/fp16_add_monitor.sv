// fp16_add_monitor.sv
// Implements the pure virtual 'sample_ports' task for the 2-input adder.

`include "uvm_macros.svh"
import uvm_pkg::*;

class fp16_add_monitor extends fp_monitor_base #(fp16_add_transaction, virtual fp16_add_if);
    `uvm_component_utils(fp16_add_monitor)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    // Implementation of the DUT-specific sample task
    virtual task sample_ports(fp16_add_transaction trans);
        trans.inputs[0] = vif.monitor_cb.a;
        trans.inputs[1] = vif.monitor_cb.b;
    endtask
    // Implementation of the DUT-specific output sampling task
    virtual task sample_output(fp16_add_transaction trans);
        trans.result = vif.monitor_cb.result;
    endtask


endclass
