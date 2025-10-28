// verif/tests/fp_classify/fp_classify_special_cases_sequence.sv
// A directed sequence that generates transactions to test all known
// special cases for floating-point classifier (NaN, Inf, Zero).

`include "uvm_macros.svh"

`include "fp16_inc.vh"
`include "fp_macros.svh"

class fp_classify_special_cases_sequence #(
    parameter int WIDTH = 16
) extends uvm_sequence #(fp_classify_transaction #(WIDTH));

    `uvm_object_param_utils(fp_classify_special_cases_sequence #(WIDTH))

    function new(string name="fp_classify_special_cases_sequence");
        super.new(name);
    endfunction

    virtual task body();
        fp_classify_transaction #(WIDTH) req;
        logic [WIDTH-1:0] normal_values[];
        logic [WIDTH-1:0] special_values[];

        // Define a queue of normal values to test
        normal_values = {
            fp_lib_pkg::float_to_fp(1.0, WIDTH),
            fp_lib_pkg::float_to_fp(-2.0, WIDTH)
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
            fp_lib_pkg::get_n_snan(WIDTH),
            fp_lib_pkg::get_denormal(WIDTH),
            fp_lib_pkg::get_n_denormal(WIDTH),
            fp_lib_pkg::get_denormal(WIDTH),
            fp_lib_pkg::get_n_denormal(WIDTH)
        };

        `uvm_info(get_type_name(), "Starting special cases sequence", UVM_LOW)

        // Test normal numbers
        foreach (normal_values[i]) begin
            `uvm_do_special_case("req", req, { req.inputs[0] == normal_values[i]; })
        end

        // Test special values
        foreach (special_values[i]) begin
            `uvm_do_special_case("req", req, { req.inputs[0] == special_values[i]; })
        end

        `uvm_info(get_type_name(), "Finished special cases sequence", UVM_LOW)

    endtask

endclass
