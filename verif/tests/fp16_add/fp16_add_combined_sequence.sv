// fp16_add_combined_sequence.sv
//
// A top-level sequence that combines directed and random tests.
// It first runs the special cases sequence, then the random sequence.

`include "uvm_macros.svh"

class fp16_add_combined_sequence extends uvm_sequence #(fp16_add_transaction);
    `uvm_object_utils(fp16_add_combined_sequence)

    function new(string name="fp16_add_combined_sequence");
        super.new(name);
    endfunction

    // Child sequences to be executed
    fp16_add_special_cases_sequence special_seq;
    fp16_add_random_sequence random_seq;

    virtual task body();
        `uvm_info("SEQ", "Starting combined sequence...", UVM_LOW)

        // 1. Run the special cases first
        `uvm_info("SEQ", "Executing special cases sub-sequence...", UVM_LOW)
        special_seq = fp16_add_special_cases_sequence::type_id::create("special_seq");
        special_seq.start(m_sequencer);

        // 2. Then, run the random sequence
        `uvm_info("SEQ", "Executing random sub-sequence...", UVM_LOW)
        random_seq = fp16_add_random_sequence::type_id::create("random_seq");
        // We can optionally override the number of random transactions here
        // random_seq.num_transactions = 50; 
        random_seq.start(m_sequencer);

        `uvm_info("SEQ", "Finished combined sequence.", UVM_LOW)
    endtask

endclass
