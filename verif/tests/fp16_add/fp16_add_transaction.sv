// fp16_add_transaction.sv
// Transaction item for the fp16_add testbench.

`include "uvm_macros.svh"
import uvm_pkg::*;

class fp16_add_transaction extends fp_transaction_base #(16);

    // `uvm_object_utils(fp16_add_transaction)

    // DUT-specific data fields
    rand logic [15:0] a;
    rand logic [15:0] b;
    // 'result' and 'golden_result' are inherited as 16-bit values.

    function new(string name="fp16_add_transaction");
        super.new(name);
    endfunction

    // Implementation of the pure virtual function from the base class
    // virtual function string convert2string();
    //     return $sformatf("a=0x%0h, b=0x%0h, result=0x%0h, golden=0x%0h",
    //                      a, b, result[15:0], golden_result[15:0]);
    // endfunction

    `uvm_object_utils_begin(fp16_add_transaction)
        `uvm_field_int(a, UVM_ALL_ON)
        `uvm_field_int(b, UVM_ALL_ON)
        `uvm_field_int(result, UVM_ALL_ON)
        `uvm_field_int(golden_result, UVM_ALL_ON)
    `uvm_object_utils_end

    // Constraint for normal values
    constraint normal_values {
        a[14:10] inside {[5'h01:5'h1E]};
        b[14:10] inside {[5'h01:5'h1E]};
    }

endclass
