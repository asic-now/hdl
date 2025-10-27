// verif/tests/fp_classify/fp_classify_random_test.sv
// Test that runs a random sequence.

`include "uvm_macros.svh"
import uvm_pkg::*;
import fp_lib_pkg::*;

class fp_classify_random_test #(
    parameter int WIDTH = 16
) extends fp_classify_base_test #(WIDTH);

    `my_uvm_component_param_utils(fp_classify_random_test #(WIDTH), "fp_classify_random_test")

    function new(string name = "fp_classify_random_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        fp_classify_random_sequence #(WIDTH) seq;
        phase.raise_objection(this);
        seq = fp_classify_random_sequence #(WIDTH)::type_id::create("seq");
        seq.start(env.agent.seqr);
        #100ns;
        phase.drop_objection(this);
    endtask

endclass
