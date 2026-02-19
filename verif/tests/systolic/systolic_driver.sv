// verif/tests/systolic/systolic_driver.sv
// Parameterized UVM driver for the systolic DUT.

`include "uvm_macros.svh"
import uvm_pkg::*;

class systolic_driver #(
    parameter ROWS = 2,
    parameter COLS = 2,
    parameter WIDTH = 4,
    parameter ACC_WIDTH = 9
) extends uvm_driver #(systolic_item #(ROWS, COLS, WIDTH, ACC_WIDTH));

    `uvm_component_param_utils(systolic_driver #(ROWS, COLS, WIDTH, ACC_WIDTH))
    
    virtual systolic_if #(ROWS, COLS, WIDTH, ACC_WIDTH) vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual systolic_if #(ROWS, COLS, WIDTH, ACC_WIDTH))::get(this, "", "vif", vif))
            `uvm_fatal("DRV", "Could not get vif")
    endfunction

    task run_phase(uvm_phase phase);
        vif.cb_drv.in_valid <= 0;
        vif.cb_drv.a <= 0;
        vif.cb_drv.b <= 0;
        
        wait(vif.rst_n === 1'b1);
        @(vif.cb_drv);

        forever begin
            seq_item_port.get_next_item(req);
            
            // Drive signals
            vif.cb_drv.a <= req.pack_a();
            vif.cb_drv.b <= req.pack_b();
            vif.cb_drv.in_valid <= 1'b1;
            
            // Wait for handshake
            do begin
                @(vif.cb_drv);
            end while (vif.cb_drv.in_ready !== 1'b1);
            
            vif.cb_drv.in_valid <= 1'b0;
            
            seq_item_port.item_done();
        end
    endtask

endclass
