// verif/tests/fp16_add/fp16_add_random_test.sv
// Test to run random stimulus for the fp16_add DUT.

`include "uvm_macros.svh"
import uvm_pkg::*;

class fp16_add_random_test extends fp16_add_base_test;
    `uvm_component_utils(fp16_add_random_test)

    function new(string name = "fp16_add_random_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        fp16_sequence2_random seq;
        phase.raise_objection(this);
        seq = fp16_sequence2_random::type_id::create("seq");
        seq.start(env.agent.seqr);
        #100ns;
        phase.drop_objection(this);
    endtask

endclass
