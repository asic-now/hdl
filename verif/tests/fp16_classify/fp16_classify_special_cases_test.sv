// fp16_classify_special_cases_test.sv
//
// A directed test that runs the special cases sequence.

`include "uvm_macros.svh"

class fp16_classify_special_cases_test extends fp16_classify_base_test;
    `uvm_component_utils(fp16_classify_special_cases_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        fp16_classify_special_cases_sequence seq;
        phase.raise_objection(this);
        
        seq = fp16_classify_special_cases_sequence::type_id::create("seq");
        seq.start(env.agent.seqr);
        
        // Add a small delay to allow the last transaction to complete
        #50ns;
        
        phase.drop_objection(this);
    endtask

endclass
