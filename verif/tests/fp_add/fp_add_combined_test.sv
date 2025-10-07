// verif/tests/fp_add/fp_add_combined_test.sv
// A test that runs the combined directed and random sequence.

`include "uvm_macros.svh"

`define FP_ADD_COMBINED_TEST(PRECISION, WIDTH) \
class PRECISION``_add_combined_test extends fp_add_base_test #(WIDTH); \
    `uvm_component_utils(PRECISION``_add_combined_test) \
    function new(string name, uvm_component parent); \
        super.new(name, parent); \
    endfunction \
    virtual task run_phase(uvm_phase phase); \
        fp_add_combined_sequence #(WIDTH) seq = fp_add_combined_sequence #(WIDTH)::type_id::create("seq"); \
        super.run_phase(phase); \
        phase.raise_objection(this); \
        seq.start(env.agent.seqr); \
        phase.drop_objection(this); \
    endtask \
endclass

`FP_ADD_RANDOM_TEST(fp16, 16)
`FP_ADD_RANDOM_TEST(fp32, 32)
`FP_ADD_RANDOM_TEST(fp64, 64)

`FP_ADD_SPECIAL_CASES_TEST(fp16, 16)
`FP_ADD_SPECIAL_CASES_TEST(fp32, 32)
`FP_ADD_SPECIAL_CASES_TEST(fp64, 64)

`FP_ADD_COMBINED_TEST(fp16, 16)
`FP_ADD_COMBINED_TEST(fp32, 32)
`FP_ADD_COMBINED_TEST(fp64, 64)