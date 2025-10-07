// verif/lib/fp_transaction2.sv
// Extends the generic transaction base class for 2-input, parameterized WIDTH floating-point operations.

`include "uvm_macros.svh"
import uvm_pkg::*;


class fp_transaction2 #(
    parameter int WIDTH = 16
) extends fp_transaction #(2, WIDTH, WIDTH);


    // Defines the categories of numbers to generate
    typedef enum { NORMAL, ZERO, INF, QNAN } fp_category_e;

    // Random variables to control the category of each input
    rand fp_category_e category_a;
    rand fp_category_e category_b;

    `uvm_object_param_utils_begin(fp_transaction2 #(WIDTH))
        `uvm_field_array_int(inputs, UVM_ALL_ON)
        `uvm_field_int(result, UVM_ALL_ON)
        `uvm_field_enum(fp_category_e, category_a, UVM_ALL_ON)
        `uvm_field_enum(fp_category_e, category_b, UVM_ALL_ON)
    `uvm_object_utils_end

    // Helper variables for bit positions, calculated as localparams
    localparam int EXP_W = fp_lib_pkg::get_exp_width(WIDTH);
    localparam int MANT_W = fp_lib_pkg::get_mant_width(WIDTH);
    localparam int SIGN_POS = WIDTH - 1;
    localparam int EXP_MSB = SIGN_POS - 1;
    localparam int EXP_LSB = MANT_W;
    localparam int MANT_MSB = MANT_W - 1;

    // Constructor
    function new(string name = "fp_transaction2");
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
            // Exponent is not all zeros or all ones
            inputs[0][EXP_MSB:EXP_LSB] != 0;
            inputs[0][EXP_MSB:EXP_LSB] != '1;
        }
        if (category_a == ZERO) {
            // Exponent and mantissa are zero
            inputs[0][EXP_MSB:0] == 0;
        }
        if (category_a == INF) {
            // Exponent is all ones, mantissa is zero
            inputs[0][EXP_MSB:EXP_LSB] == '1;
            inputs[0][MANT_MSB:0] == 0;
        }
        if (category_a == QNAN) {
            // Exponent is all ones, mantissa is non-zero
            inputs[0][EXP_MSB:EXP_LSB] == '1;
            inputs[0][MANT_MSB:0] != 0;
        }

        // --- Constraint for inputs[1] (b) ---
        solve category_b before inputs[1];
        if (category_b == NORMAL) {
            inputs[1][EXP_MSB:EXP_LSB] != 0;
            inputs[1][EXP_MSB:EXP_LSB] != '1;
        }
        if (category_b == ZERO) {
            inputs[1][EXP_MSB:0] == 0;
        }
        if (category_b == INF) {
            inputs[1][EXP_MSB:EXP_LSB] == '1;
            inputs[1][MANT_MSB:0] == 0;
        }
        if (category_b == QNAN) {
            inputs[1][EXP_MSB:EXP_LSB] == '1;
            inputs[1][MANT_MSB:0] != 0;
        }
    }

endclass
