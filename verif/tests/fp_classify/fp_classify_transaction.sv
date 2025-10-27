// verif/tests/fp_classify/fp_classify_transaction.sv
// Transaction item for the fp_classify testbench.

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
} fp_classify_outputs_s;


class fp_classify_transaction #(
    parameter int WIDTH = 16
) extends base_transaction #(1, WIDTH, 10);

    // Override:
    fp_classify_outputs_s result;

    // Defines the categories of numbers to generate
    typedef enum { NORMAL, ZERO, INF, QNAN } fp_category_e;

    // Random variables to control the category of each input
    rand fp_category_e category_a;

    `uvm_object_param_utils_begin(fp_classify_transaction #(WIDTH))
        `uvm_field_array_int(inputs, UVM_ALL_ON)
        `uvm_field_int(result, UVM_ALL_ON)
        `uvm_field_enum(fp_category_e, category_a, UVM_ALL_ON)
    `uvm_object_utils_end

    // Helper variables for bit positions, calculated as localparams
    localparam int EXP_W = fp_lib_pkg::get_exp_width(WIDTH);
    localparam int MANT_W = fp_lib_pkg::get_mant_width(WIDTH);
    localparam int SIGN_POS = WIDTH - 1;
    localparam int EXP_MSB = SIGN_POS - 1;
    localparam int EXP_LSB = MANT_W;
    localparam int MANT_MSB = MANT_W - 1;

    // Constructor
    function new(string name="fp_classify_transaction");
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
    }

    // Convert transaction to a string for printing
    virtual function string convert2string();
        string s;
        s = $sformatf("[%s]: in=0x%h", get_name(), inputs[0]);
        // Check if result has been set by the monitor to avoid printing empty structs
        if (|result) s = {s, $sformatf(" -> result: %p", result)};
        return s;
    endfunction

    // Override compare for the struct-based result
    virtual function string compare(input uvm_sequence_item golden_trans_item, output bit is_match);
        fp_classify_transaction #(WIDTH) golden_trans;
        if (!$cast(golden_trans, golden_trans_item)) begin
            `uvm_fatal("CAST_FAIL", "Failed to cast golden transaction in fp_classify_transaction::compare()")
            is_match = 0;
            return "FATAL: Cast failed in fp_classify_transaction::compare()";
        end

        // The 'result' member in the base class is not used here.
        // We compare the struct fields directly.
        is_match = (result == golden_trans.result);
        if (is_match) begin
            return convert2string();
        end else begin
            string s;
            s = $sformatf("[%s]: in=0x%h", get_name(), inputs[0]);
            s = {s, $sformatf(" -> DUT=0x%h, MODEL=0x%h", result, golden_trans.result)};
            return s;
        end
    endfunction

endclass
