// verif/lib/base_test.sv
// Generic base test that provides common functionality for all testbenches.

`include "uvm_macros.svh"
import uvm_pkg::*;

class base_test #(type T_ENV = uvm_env) extends uvm_test;
    `uvm_component_param_utils(base_test #(T_ENV))

    T_ENV env;
    uvm_table_printer printer;
    int pipeline_latency = -1;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        printer = new();
        printer.knobs.depth = 5;
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // Get the pipeline latency from the config DB (set in tb_top).
        if (!uvm_config_db#(int)::get(this, "", "pipeline_latency", pipeline_latency)) begin
            `uvm_fatal(get_type_name(), "Pipeline latency not found in uvm_config_db. Was it set in tb_top?")
        end

        // Build the specific environment
        env = T_ENV::type_id::create("env", this);
    endfunction

    virtual function void end_of_elaboration_phase(uvm_phase phase);
        uvm_top.print_topology(printer);
    endfunction

endclass