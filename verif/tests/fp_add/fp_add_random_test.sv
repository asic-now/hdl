// verif/tests/fp_add/fp_add_random_test.sv
// Test that runs a random sequence.

`include "uvm_macros.svh"
import uvm_pkg::*;
import fp_lib_pkg::*;

class fp_add_random_test #(
    parameter int WIDTH = 16
) extends fp_add_base_test #(WIDTH);
    // `uvm_component_param_utils(fp_add_random_test #(WIDTH))
    `my_uvm_component_param_utils(fp_add_random_test #(WIDTH), "fp_add_random_test")

    function new(string name = "fp_add_random_test", uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        fp_sequence2_random #(WIDTH) seq;
        // super.run_phase(phase);
        phase.raise_objection(this);
        seq = fp_sequence2_random #(WIDTH)::type_id::create("seq");
        seq.start(env.agent.seqr);
        #100ns;
        phase.drop_objection(this);
    endtask

endclass
