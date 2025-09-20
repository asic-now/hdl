// fp16_classify_transaction.sv
// Transaction item for the fp16_classify testbench.

`include "uvm_macros.svh"
import uvm_pkg::*;

typedef struct packed {
    bit is_snan;            // 'h200
    bit is_qnan;            // 'h100
    bit is_neg_inf;         // 'h080
    bit is_neg_normal;      // 'h040
    bit is_neg_denormal;    // 'h020
    bit is_neg_zero;        // 'h010
    bit is_pos_zero;        // 'h008
    bit is_pos_denormal;    // 'h004
    bit is_pos_normal;      // 'h002
    bit is_pos_inf;         // 'h001
} fp16_classify_outputs_s;


class fp16_classify_transaction extends fp_transaction_base #(16);

    // `uvm_object_utils(fp16_classify_transaction)

    // DUT-specific data fields
    rand logic [15:0] in;
    // 'result' and 'golden_result' are inherited as 16-bit values, we need fp16_classify_outputs_s.
    fp16_classify_outputs_s result; // dut_outputs
    fp16_classify_outputs_s golden_result; // ref_outputs

    function new(string name="fp16_classify_transaction");
        super.new(name);
    endfunction

    `uvm_object_utils_begin(fp16_classify_transaction)
        `uvm_field_int(in, UVM_ALL_ON)
        `uvm_field_int(result, UVM_ALL_ON)
        `uvm_field_int(golden_result, UVM_ALL_ON)
    `uvm_object_utils_end

    // Constraint for normal values
    constraint normal_values {
        // in inside {[5'h01:5'h1E]};
    }

    // Comparison function for the scoreboard
    virtual function bit do_compare(uvm_object rhs, uvm_comparer comparer);
        fp16_classify_transaction tx;
        if (!$cast(tx, rhs)) begin
            `uvm_error("do_compare", "Cast failed")
            return 0;
        end
        return (super.do_compare(rhs, comparer) &&
                tx.golden_result == this.result);
    endfunction

    // Convert transaction to a string for printing
    // virtual function string convert2string();
    //     return $sformatf("a=0x%0h, b=0x%0h, result=0x%0h, golden=0x%0h",
    //                      a, b, result[15:0], golden_result[15:0]);
    // endfunction
    virtual function string convert2string();
        // return $sformatf("in: 0x%04h, result: %p, golden_result: %p", in, result, golden_result);
         string s;
         s = $sformatf("in: 0x%04h", in);
         // Check if result has been set by the monitor to avoid printing empty structs
         if (|result) s = {s, $sformatf(", result: %p", result)};
         // Check if golden_result has been set by the model
         if (|golden_result) s = {s, $sformatf(", golden_result: %p", golden_result)};
         return s;
    endfunction
endclass
