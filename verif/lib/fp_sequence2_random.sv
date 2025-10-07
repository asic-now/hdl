// verif/lib/fp_sequence2_random.sv
// Generic sequence to generate random transactions for 2-input DUTs with parameterized WIDTH.

`include "uvm_macros.svh"
import uvm_pkg::*;

class fp_sequence2_random #(
    parameter int WIDTH = 16
) extends uvm_sequence #(fp_transaction2 #(WIDTH));

    `uvm_object_param_utils(fp_sequence2_random #(WIDTH))

    int num_trans = 100;

    function new(string name = "fp_sequence2_random");
        super.new(name);
    endfunction

    virtual task body();
        repeat (num_trans) begin
            fp_transaction2 #(WIDTH) req;
            req = fp_transaction2 #(WIDTH)::type_id::create("req");
            start_item(req);
            assert(req.randomize());
            finish_item(req);
        end
    endtask

endclass
