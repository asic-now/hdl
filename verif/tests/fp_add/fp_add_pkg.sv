// verif/tests/fp_add/fp_add_pkg.sv
// Main package for the parameterized fp_add UVM testbench.

package fp_add_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    import fp_lib_pkg::*;

    // Include all component files
    `include "fp_add_driver.sv"
    `include "fp_add_monitor.sv"
    `include "fp_add_agent.sv"
    `include "fp_add_model.sv"
    `include "fp_add_env.sv"

    // Sequences & Tests
    `include "fp_add_base_test.sv"
    `include "fp_add_random_test.sv"
    `include "fp_add_special_cases_sequence.sv"
    `include "fp_add_special_cases_test.sv"
    `include "fp_add_combined_sequence.sv"
    `include "fp_add_combined_test.sv"


    // Macro to create wrapper classes for different precisions
    `define CREATE_FP_TEST_WRAPPER(width_val, base_class, wrapper_name) \
        class wrapper_name extends base_class#(.WIDTH(width_val)); \
            `uvm_component_utils(wrapper_name) \
            function new(string name=`"wrapper_name`", uvm_component parent=null); \
                super.new(name, parent); \
            endfunction \
        endclass

    `CREATE_FP_TEST_WRAPPER(16, fp_add_random_test,        fp16_add_random_test        )
    `CREATE_FP_TEST_WRAPPER(16, fp_add_special_cases_test, fp16_add_special_cases_test )
    `CREATE_FP_TEST_WRAPPER(16, fp_add_combined_test,      fp16_add_combined_test      )
    `CREATE_FP_TEST_WRAPPER(32, fp_add_random_test,        fp32_add_random_test        )
    `CREATE_FP_TEST_WRAPPER(32, fp_add_special_cases_test, fp32_add_special_cases_test )
    `CREATE_FP_TEST_WRAPPER(32, fp_add_combined_test,      fp32_add_combined_test      )
    `CREATE_FP_TEST_WRAPPER(64, fp_add_random_test,        fp64_add_random_test        )
    `CREATE_FP_TEST_WRAPPER(64, fp_add_special_cases_test, fp64_add_special_cases_test )
    `CREATE_FP_TEST_WRAPPER(64, fp_add_combined_test,      fp64_add_combined_test      )

    // Cleanup the macro
    `undef CREATE_FP_TEST_WRAPPER

endpackage
