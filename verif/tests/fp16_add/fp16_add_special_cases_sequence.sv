// verif/tests/fp16_add/fp16_add_special_cases_sequence.sv
//
// A directed sequence that generates transactions to test all known
// special cases for floating-point addition (NaN, Inf, Zero).

`include "uvm_macros.svh"

`include "fp16_inc.vh"
`include "fp_macros.svh"

class fp16_add_special_cases_sequence extends uvm_sequence #(fp16_transaction2);
    `uvm_object_utils(fp16_add_special_cases_sequence)

    function new(string name="fp16_add_special_cases_sequence");
        super.new(name);
    endfunction

    virtual task body();
        fp16_transaction2 req;
        
        `uvm_info(get_type_name(), "Starting special cases sequence", UVM_LOW)

        // Case 1: sNaN + Normal -> qNaN
        `uvm_do_special_case("req_snan_1", req, { req.inputs[0] == `FP16_SNAN; req.inputs[1] == 16'h3C00 /* 1.0 */;})
        
        // Case 2: Normal + sNaN -> qNaN
        `uvm_do_special_case("req_snan_2", req, { req.inputs[1] == `FP16_SNAN; req.inputs[0] == 16'h3C00 /* 1.0 */;})
        
        // Case 3: -sNan + Normal -> -qNaN
        `uvm_do_special_case("req_snan_3", req, { req.inputs[0] == `FP16_N_SNAN; req.inputs[1] == 16'h4000 /* 2.0 */;})
        
        // Case 4: Normal + -sNan -> -qNaN
        `uvm_do_special_case("req_snan_4", req, { req.inputs[1] == `FP16_N_SNAN; req.inputs[0] == 16'h4000 /* 2.0 */;})
        
        // Case 5: qNaN + Normal -> qNaN
        `uvm_do_special_case("req_qnan_1", req, { req.inputs[0] == `FP16_QNAN; req.inputs[1] == 16'h3C00 /* 1.0 */;})
        
        // Case 6: Normal + qNaN -> qNaN
        `uvm_do_special_case("req_qnan_2", req, { req.inputs[1] == `FP16_QNAN; req.inputs[0] == 16'h3C00 /* 1.0 */;})
        
        // Case 7: -qNaN + Normal -> -qNaN
        `uvm_do_special_case("req_qnan_3", req, { req.inputs[0] == `FP16_N_QNAN; req.inputs[1] == 16'h4000 /* 2.0 */;})
        
        // Case 8: Normal + -qNaN -> -qNaN
        `uvm_do_special_case("req_qnan_4", req, { req.inputs[1] == `FP16_N_QNAN; req.inputs[0] == 16'h4000 /* 2.0 */;})
        
        // Case 9: +Inf + +Inf -> +Inf
        `uvm_do_special_case("req_inf_1", req, { req.inputs[0] == `FP16_P_INF; req.inputs[1] == `FP16_P_INF;})
        
        // Case 10: -Inf + -Inf -> -Inf
        `uvm_do_special_case("req_inf_2", req, { req.inputs[0] == `FP16_N_INF; req.inputs[1] == `FP16_N_INF;})
        
        // Case 11: +Inf + -Inf -> qNaN (Invalid operation)
        `uvm_do_special_case("req_inf_3", req, { req.inputs[0] == `FP16_P_INF; req.inputs[1] == `FP16_N_INF;})
        
        // Case 12: -Inf + +Inf -> qNaN (Invalid operation)
        `uvm_do_special_case("req_inf_4", req, { req.inputs[0] == `FP16_N_INF; req.inputs[1] == `FP16_P_INF;})
        
        // Case 13: +Inf + Normal -> +Inf
        `uvm_do_special_case("req_inf_5", req, { req.inputs[0] == `FP16_P_INF; req.inputs[1] == 16'hC000 /* -2.0 */;})
        
        // Case 14: +0 + -0 -> +0
        `uvm_do_special_case("req_zero_1", req, { req.inputs[0] == `FP16_P_ZERO; req.inputs[1] == `FP16_N_ZERO;})
        
        // Case 15: -0 + -0 -> -0
        `uvm_do_special_case("req_zero_2", req, { req.inputs[0] == `FP16_N_ZERO; req.inputs[1] == `FP16_N_ZERO;})
        
        // Case 16: Normal + +0 -> Normal
        `uvm_do_special_case("req_zero_2", req, { req.inputs[0] == 16'hC200 /* -4.0 */; req.inputs[1] == `FP16_P_ZERO;})

        `uvm_info("SEQ", "Finished special cases sequence", UVM_LOW)

    endtask

endclass
