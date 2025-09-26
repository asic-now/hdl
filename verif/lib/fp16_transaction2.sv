// verif/lib/fp16_transaction2.sv
// Extends the generic transaction base class for 2-input, 16-bit floating-point operations.

`include "uvm_macros.svh"
import uvm_pkg::*;

class fp16_transaction2 extends fp_transaction #(2, 16, 16);

    // Defines the categories of numbers to generate
    typedef enum { NORMAL, ZERO, INF, QNAN } fp_category_e;

    // Random variables to control the category of each input
    rand fp_category_e category_a;
    rand fp_category_e category_b;

    `uvm_object_utils_begin(fp16_transaction2)
        `uvm_field_array_int(inputs, UVM_ALL_ON)
        `uvm_field_int(result, UVM_ALL_ON)
        `uvm_field_enum(fp_category_e, category_a, UVM_ALL_ON)
        `uvm_field_enum(fp_category_e, category_b, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name="fp16_transaction2");
        super.new(name);
    endfunction

    // Controls the probability distribution of the different categories.
    // 80% of inputs will be normal numbers, 20% will be special values.
    constraint category_dist_c {
        category_a dist { NORMAL := 80, ZERO := 5, INF := 10, QNAN := 5 };
        category_b dist { NORMAL := 80, ZERO := 5, INF := 10, QNAN := 5 };
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

        // --- Constraint for inputs[1] (b) ---
        solve category_b before inputs[1];
        if (category_b == NORMAL) {
            inputs[1][14:10] inside {[5'h01:5'h1E]};
        }
        if (category_b == ZERO) {
            inputs[1][14:0] == 0;
        }
        if (category_b == INF) {
            inputs[1][14:10] == 5'h1F;
            inputs[1][9:0]   == 0;
        }
        if (category_b == QNAN) {
            inputs[1][14:10] == 5'h1F;
            inputs[1][9:0]   != 0;
        }
    }

endclass
