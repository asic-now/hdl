// verif/tests/fp_add/fp_add_special_cases_test.sv

`include "uvm_macros.svh"

`define FP_ADD_SPECIAL_CASES_TEST(PRECISION, WIDTH) \
class PRECISION``_add_special_cases_test extends fp_add_base_test #(WIDTH); \
    `uvm_component_utils(PRECISION``_add_special_cases_test) \
    function new(string name, uvm_component parent); \
        super.new(name, parent); \
    endfunction \
    virtual task run_phase(uvm_phase phase); \
        fp_add_special_cases_sequence #(WIDTH) seq = fp_add_special_cases_sequence #(WIDTH)::type_id::create("seq"); \
        super.run_phase(phase); \
        phase.raise_objection(this); \
        seq.start(env.agent.seqr); \
        phase.drop_objection(this); \
    endtask \
endclass
