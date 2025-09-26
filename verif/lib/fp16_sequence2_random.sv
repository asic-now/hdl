// verif/lib/fp16_sequence2_random.sv
// Generic sequence to generate random transactions for 2-input DUTs.

`include "uvm_macros.svh"
import uvm_pkg::*;

class fp16_sequence2_random extends uvm_sequence #(fp16_transaction2);
    `uvm_object_utils(fp16_sequence2_random)

    function new(string name="fp16_sequence2_random");
        super.new(name);
    endfunction

    virtual task body();
        fp16_transaction2 req;
        repeat (100) begin
            req = fp16_transaction2::type_id::create("req");
            start_item(req);
            assert(req.randomize());
            finish_item(req);
        end
    endtask

endclass
