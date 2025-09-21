// verif/tests/fp16_classify/fp16_classify_random_sequence.sv
// Sequence to generate random transactions for the fp16_classify DUT.

`include "uvm_macros.svh"
import uvm_pkg::*;

class fp16_classify_random_sequence extends uvm_sequence #(fp16_classify_transaction);
    `uvm_object_utils(fp16_classify_random_sequence)

    function new(string name="fp16_classify_random_sequence");
        super.new(name);
    endfunction

    virtual task body();
        fp16_classify_transaction req;
        repeat (100) begin
            req = fp16_classify_transaction::type_id::create("req");
            start_item(req);
            assert(req.randomize());
            finish_item(req);
        end
    endtask

endclass
