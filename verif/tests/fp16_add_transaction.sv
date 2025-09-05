// fp16_add_transaction.sv
// Specific transaction for the fp16_add DUT.

`include "uvm_macros.svh"
import uvm_pkg::*;

class fp16_add_transaction extends fp_transaction_base;

    `uvm_object_utils(fp16_add_transaction)

    // DUT-specific data fields
    rand logic [15:0] a;
    rand logic [15:0] b;

    function new(string name = "fp16_add_transaction");
        super.new(name);
    endfunction

    // Implementation of the pure virtual function from the base class
    virtual function string convert2string();
        return $sformatf("a=0x%0h, b=0x%0h, result=0x%0h, golden=0x%0h",
                         a, b, result[15:0], golden_result[15:0]);
    endfunction

endclass
