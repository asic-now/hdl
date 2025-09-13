// fp16_add_driver.sv
// Drives transactions to the fp16_add DUT.

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
        if(!uvm_config_db#(virtual fp16_add_if)::get(this, "", "dut_vif", vif))
            `uvm_fatal("NOVIF", "Could not get virtual interface handle")
    endfunction

    virtual task run_phase(uvm_phase phase);
        // Wait for reset to de-assert before starting
        @(posedge vif.rst_n);
        // Add one cycle delay for synchronization with monitor
        @(vif.driver_cb);

        forever begin
            seq_item_port.get_next_item(req);
            drive_transfer(req);
            seq_item_port.item_done();
        end
    endtask

    virtual task drive_transfer(fp16_add_transaction trans);
        @(vif.driver_cb);
        vif.driver_cb.a <= trans.a;
        vif.driver_cb.b <= trans.b;
        `uvm_info("DRIVER", $sformatf("Drove transaction: a=0x%h, b=0x%h", trans.a, trans.b), UVM_HIGH)
    endtask

endclass
