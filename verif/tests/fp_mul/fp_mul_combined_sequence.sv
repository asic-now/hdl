// verif/tests/fp_mul/fp_mul_combined_sequence.sv
// A sequence that runs both random and special cases sequences.

`include "uvm_macros.svh"

class fp_mul_combined_sequence #(
    parameter int WIDTH = 16
) extends uvm_sequence #(fp_transaction2 #(WIDTH));

    `uvm_object_param_utils(fp_mul_combined_sequence #(WIDTH))

    function new(string name = "fp_mul_combined_sequence");
        super.new(name);
    endfunction

    // Child sequences to be executed
    fp_mul_special_cases_sequence #(WIDTH) special_seq;
    fp_sequence2_random #(WIDTH) random_seq;

    virtual task body();
        `uvm_info("SEQ", "Starting combined sequence...", UVM_LOW)

        // 1. Run the special cases first
        `uvm_info("SEQ", "Executing special cases sub-sequence...", UVM_LOW)
        special_seq = fp_mul_special_cases_sequence #(WIDTH)::type_id::create("special_seq");
        special_seq.start(m_sequencer);
        // `uvm_do(special_seq)

        // 2. Then, run the random sequence
        `uvm_info("SEQ", "Executing random sub-sequence...", UVM_LOW)
        random_seq = fp_sequence2_random #(WIDTH)::type_id::create("rand_seq");
        // We can optionally override the number of random transactions here
        // random_seq.num_transactions = 50; 
        random_seq.start(m_sequencer);
        // `uvm_do(random_seq)

        `uvm_info("SEQ", "Finished combined sequence.", UVM_LOW)
    endtask

endclass
