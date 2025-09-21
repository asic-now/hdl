// verif/tests/fp16_add/fp16_add_random_test.sv
// A specific test that runs a random sequence.

`include "uvm_macros.svh"
import uvm_pkg::*;

class fp16_add_random_test extends fp16_add_base_test;
    `uvm_component_utils(fp16_add_random_test)

    function new(string name = "fp16_add_random_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        fp16_add_random_sequence seq;
        phase.raise_objection(this);
        seq = fp16_add_random_sequence::type_id::create("seq");
        seq.start(env.agent.seqr);
        #100ns;
        phase.drop_objection(this);
    endtask

endclass
