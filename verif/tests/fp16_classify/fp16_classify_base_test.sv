// fp16_classify_base_test.sv
// Base test class for the fp16_classify verification environment.

`include "uvm_macros.svh"
import uvm_pkg::*;

class fp16_classify_base_test extends uvm_test;
    `uvm_component_utils(fp16_classify_base_test)

    fp16_classify_env env;
    uvm_table_printer printer;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        printer = new();
        printer.knobs.depth = 5;
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = fp16_classify_env::type_id::create("env", this);
    endfunction

    virtual function void end_of_elaboration_phase(uvm_phase phase);
        uvm_top.print_topology(printer);
    endfunction

endclass
