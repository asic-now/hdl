// fp16_add_base_test.sv
// Base test class for the fp16_add environment.

`include "uvm_macros.svh"
import uvm_pkg::*;

class fp16_add_base_test extends uvm_test;
    `uvm_component_utils(fp16_add_base_test)

    fp16_add_env env;
    uvm_table_printer printer;
    int pipeline_latency = 3; // Default value

    function new(string name, uvm_component parent);
        super.new(name, parent);
        printer = new();
        printer.knobs.depth = 5;
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        // Read the pipeline latency from the command line plusargs
        // If the plusarg is not found, it will use the default value of 3.
        if ($value$plusargs("pipeline_latency=%0d", pipeline_latency)) begin
            `uvm_info(get_type_name(), $sformatf("Pipeline latency set from command line: %0d", pipeline_latency), UVM_LOW)
        end else begin
            `uvm_info(get_type_name(), $sformatf("Using default pipeline latency: %0d", pipeline_latency), UVM_LOW)
        end

        // Set the latency in the config_db for the monitor to retrieve
        uvm_config_db#(int)::set(this, "env.agent.monitor", "pipeline_latency", pipeline_latency);

        // Build the environment
        env = fp16_add_env::type_id::create("env", this);
    endfunction

    virtual function void end_of_elaboration_phase(uvm_phase phase);
        uvm_top.print_topology(printer);
    endfunction

endclass
