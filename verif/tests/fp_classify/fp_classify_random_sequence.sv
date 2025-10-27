// verif/tests/fp_classify/fp_classify_random_sequence.sv
// Sequence to generate random transactions for the fp_classify DUT.

`include "uvm_macros.svh"
import uvm_pkg::*;

class fp_classify_random_sequence #(
    parameter int WIDTH = 16
) extends uvm_sequence #(fp_classify_transaction #(WIDTH));

    `uvm_object_param_utils(fp_classify_random_sequence #(WIDTH))

    int num_trans = 100;

    function new(string name="fp_classify_random_sequence");
        super.new(name);
    endfunction

    virtual task body();
        fp_classify_transaction #(WIDTH) req;
        repeat (num_trans) begin
            req = fp_classify_transaction #(WIDTH)::type_id::create("req");
            start_item(req);
            assert(req.randomize());
            finish_item(req);
        end
    endtask

endclass
