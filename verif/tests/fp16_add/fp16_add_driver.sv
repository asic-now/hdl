// fp16_add_driver.sv
// DUT-specific driver.

`include "uvm_macros.svh"
import uvm_pkg::*;

class fp16_add_driver extends uvm_driver #(fp16_add_transaction);
    `uvm_component_utils(fp16_add_driver)

    virtual fp16_add_if vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual fp16_add_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal("NOVIF", "Virtual interface must be set for driver!")
        end
    endfunction

    virtual task run_phase(uvm_phase phase);
        vif.rst_n <= 0;
        vif.a <= 0;
        vif.b <= 0;
        repeat (5) @(vif.cb);
        vif.rst_n <= 1;
        @(vif.cb);

        forever begin
            seq_item_port.get_next_item(req);
            @(vif.cb);
            vif.a <= req.a;
            vif.b <= req.b;
            seq_item_port.item_done();
        end
    endtask
endclass
