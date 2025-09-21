// verif/tests/fp16_classify/fp16_classify_transaction.sv
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


class fp16_classify_transaction extends fp_transaction_base #(16, 1);

    // Override:
    fp16_classify_outputs_s result; // dut_outputs

    // Defines the categories of numbers to generate
    typedef enum { NORMAL, ZERO, INF, QNAN } fp_category_e;

    // Random variables to control the category of each input
    rand fp_category_e category_a;

    `uvm_object_utils_begin(fp16_classify_transaction)
        `uvm_field_array_int(inputs, UVM_ALL_ON)
        `uvm_field_int(result, UVM_ALL_ON)
        `uvm_field_enum(fp_category_e, category_a, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name="fp16_classify_transaction");
        super.new(name);
    endfunction

    // Controls the probability distribution of the different categories.
    // 80% of inputs will be normal numbers, 20% will be special values.
    constraint category_dist_c {
        category_a dist { NORMAL := 80, ZERO := 5, INF := 10, QNAN := 5 };
    }

    // Generates the bit-patterns for the inputs based on the chosen category.
    constraint values_c {
        // --- Constraint for inputs[0] (a) ---
        solve category_a before inputs[0];
        if (category_a == NORMAL) {
            inputs[0][14:10] inside {[5'h01:5'h1E]}; // Non-special exponent
        }
        if (category_a == ZERO) {
            inputs[0][14:0] == 0; // Mantissa and exponent are zero
        }
        if (category_a == INF) {
            inputs[0][14:10] == 5'h1F;
            inputs[0][9:0]   == 0;
        }
        if (category_a == QNAN) {
            inputs[0][14:10] == 5'h1F;
            inputs[0][9:0]   != 0;
        }
    }

    // Convert transaction to a string for printing
    virtual function string convert2string();
         string s;
         s = $sformatf("in: 0x%04h", inputs[0]);
         // Check if result has been set by the monitor to avoid printing empty structs
         if (|result) s = {s, $sformatf(", result: %p", result)};
         return s;
    endfunction

endclass
