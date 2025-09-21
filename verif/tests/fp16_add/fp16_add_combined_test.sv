// verif/tests/fp16_add/fp16_add_combined_test.sv
//
// A test that runs the combined directed and random sequence.

`include "uvm_macros.svh"

class fp16_add_combined_test extends fp16_add_base_test;
    `uvm_component_utils(fp16_add_combined_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        fp16_add_combined_sequence seq;
        phase.raise_objection(this);
        
        seq = fp16_add_combined_sequence::type_id::create("seq");
        seq.start(env.agent.seqr);
        
        #200ns; // Allow time for all sequences to complete
        
        phase.drop_objection(this);
    endtask

endclass
