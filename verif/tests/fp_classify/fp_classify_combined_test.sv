// verif/tests/fp_classify/fp_classify_combined_test.sv
// A test that runs the combined directed and random sequence.

`include "uvm_macros.svh"
import uvm_pkg::*;
import fp_lib_pkg::*;

class fp_classify_combined_test #(
    parameter int WIDTH = 16
) extends fp_classify_base_test #(WIDTH);

    `my_uvm_component_param_utils(fp_classify_combined_test #(WIDTH), "fp_classify_combined_test")

    function new(string name="fp_classify_combined_test", uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        fp_classify_combined_sequence #(WIDTH) seq;
        phase.raise_objection(this);
        seq = fp_classify_combined_sequence #(WIDTH)::type_id::create("seq");
        seq.start(env.agent.seqr);
        #100ns;
        phase.drop_objection(this);
    endtask

endclass
