// verif/tests/systolic/systolic_monitor.sv
// Parameterized UVM monitor for the systolic DUT.

`include "uvm_macros.svh"
import uvm_pkg::*;

class systolic_monitor #(
    parameter ROWS = 2,
    parameter COLS = 2,
    parameter WIDTH = 4,
    parameter ACC_WIDTH = 9
) extends uvm_monitor;

    `uvm_component_param_utils(systolic_monitor #(ROWS, COLS, WIDTH, ACC_WIDTH))

    virtual systolic_if #(ROWS, COLS, WIDTH, ACC_WIDTH) vif;
    uvm_analysis_port #(systolic_item #(ROWS, COLS, WIDTH, ACC_WIDTH)) ap_in;
    uvm_analysis_port #(systolic_item #(ROWS, COLS, WIDTH, ACC_WIDTH)) ap_out;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap_in = new("ap_in", this);
        ap_out = new("ap_out", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual systolic_if #(ROWS, COLS, WIDTH, ACC_WIDTH))::get(this, "", "vif", vif))
            `uvm_fatal("MON", "Could not get vif")
    endfunction

    task run_phase(uvm_phase phase);
        fork
            monitor_input();
            monitor_output();
        join
    endtask

    task monitor_input();
        systolic_item #(ROWS, COLS, WIDTH, ACC_WIDTH) item;
        forever begin
            @(vif.cb_mon);
            if (vif.cb_mon.in_valid && vif.cb_mon.in_ready) begin
                item = systolic_item #(ROWS, COLS, WIDTH, ACC_WIDTH)::type_id::create("item_in");
                item.unpack_a(vif.cb_mon.a);
                item.unpack_b(vif.cb_mon.b);
                `uvm_info("MON", $sformatf("Sampled Input: A[0][0]=%0d B[0][0]=%0d", item.a_matrix[0][0], item.b_matrix[0][0]), UVM_HIGH)
                ap_in.write(item);
            end
        end
    endtask

    task monitor_output();
        systolic_item #(ROWS, COLS, WIDTH, ACC_WIDTH) item;
        forever begin
            @(vif.cb_mon);
            if (vif.cb_mon.out_valid) begin
                item = systolic_item #(ROWS, COLS, WIDTH, ACC_WIDTH)::type_id::create("item_out");
                item.unpack_c(vif.cb_mon.c);
                `uvm_info("MON", $sformatf("Sampled Output: C[0][0]=%0d", item.c_matrix[0][0]), UVM_HIGH)
                ap_out.write(item);
            end
        end
    endtask

endclass
