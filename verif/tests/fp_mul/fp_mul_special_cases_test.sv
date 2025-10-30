// verif/tests/fp_mul/fp_mul_special_cases_test.sv
// A directed test that runs the special cases sequence.

`include "uvm_macros.svh"
import uvm_pkg::*;
import fp_lib_pkg::*;

class fp_mul_special_cases_test #(
    parameter int WIDTH = 16
) extends fp_mul_base_test #(WIDTH);
    // `uvm_component_param_utils(fp_mul_special_cases_test #(WIDTH))
    `my_uvm_component_param_utils(fp_mul_special_cases_test #(WIDTH), "fp_mul_special_cases_test")

    function new(string name="fp_mul_special_cases_test", uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        fp_mul_special_cases_sequence #(WIDTH) seq;
        // super.run_phase(phase);
        phase.raise_objection(this);
        seq = fp_mul_special_cases_sequence #(WIDTH)::type_id::create("seq");
        seq.start(env.agent.seqr);
        #100ns;
        phase.drop_objection(this);
    endtask

endclass
