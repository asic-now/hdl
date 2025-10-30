// verif/tests/fp_add/fp_add_special_cases_sequence.sv
// A directed sequence that generates transactions for special FP values.

`include "uvm_macros.svh"

`include "fp16_inc.vh"
`include "grs_round.vh"
`include "fp_macros.svh"

class fp_add_special_cases_sequence #(
    parameter int WIDTH = 16
) extends uvm_sequence #(fp_transaction2 #(WIDTH));

    `uvm_object_param_utils(fp_add_special_cases_sequence #(WIDTH))

    function new(string name = "fp_add_special_cases_sequence");
        super.new(name);
    endfunction

    virtual task body();
        fp_transaction2 #(WIDTH) req;
        logic [WIDTH-1:0] normal_values[];
        logic [WIDTH-1:0] special_values[];

        // Define a queue of normal values to test
        normal_values = {
            fp_lib_pkg::float_to_fp(42.0, WIDTH),
            fp_lib_pkg::float_to_fp(-1.25, WIDTH)
        };

        // Define a queue of special values to test
        special_values = {
            fp_lib_pkg::get_p_zero(WIDTH),
            fp_lib_pkg::get_n_zero(WIDTH),
            fp_lib_pkg::get_p_inf(WIDTH),
            fp_lib_pkg::get_n_inf(WIDTH),
            fp_lib_pkg::get_qnan(WIDTH),
            fp_lib_pkg::get_n_qnan(WIDTH),
            fp_lib_pkg::get_snan(WIDTH),
            fp_lib_pkg::get_n_snan(WIDTH)
        };

        `uvm_info(get_type_name(), "Starting special cases sequence", UVM_LOW)

        // Test two special value inputs with all permutations
        foreach (special_values[i]) begin
            foreach (special_values[j]) begin
                `uvm_do_special_case("req", req, {
                    req.inputs[0] == special_values[i];
                    req.inputs[1] == special_values[j];
                    req.rounding_mode == `RNE; // Keep rounding mode constant for special cases
                })
            end
        end

        // Test normal number and special value inputs with all permutations
        foreach (special_values[i]) begin
            foreach (normal_values[j]) begin
                `uvm_do_special_case("req", req, {
                    req.inputs[0] == special_values[i];
                    req.inputs[1] == normal_values[j];
                    req.rounding_mode == `RNE;
                })
                `uvm_do_special_case("req", req, {
                    req.inputs[0] == normal_values[j];
                    req.inputs[1] == special_values[i];
                    req.rounding_mode == `RNE;
                })
            end
        end

        `uvm_info(get_type_name(), "Finished special cases sequence", UVM_LOW)

    endtask

endclass
