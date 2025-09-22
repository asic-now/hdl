// verif/tests/fp16_classify/fp16_classify_special_cases_sequence.sv
//
// A directed sequence that generates transactions to test all known
// special cases for floating-point classifier (NaN, Inf, Zero).

`include "uvm_macros.svh"

`include "fp16_inc.vh"
`include "fp_macros.svh"

class fp16_classify_special_cases_sequence extends uvm_sequence #(fp16_classify_transaction);
    `uvm_object_utils(fp16_classify_special_cases_sequence)

    function new(string name="fp16_classify_special_cases_sequence");
        super.new(name);
    endfunction

    virtual task body();
        fp16_classify_transaction req;
        
        `uvm_info(get_type_name(), "Starting special cases sequence", UVM_LOW)

        // Case 1: Normal
        `uvm_do_special_case("req_p_norm", req, { req.inputs[0] == 16'h3C00 /* 1.0 */; })
        
        // Case 2: -Normal
        `uvm_do_special_case("req_n_norm", req, { req.inputs[0] == 16'hC000 /* -2.0 */; })
        
        // Case 3: sNaN
        `uvm_do_special_case("req_p_snan", req, { req.inputs[0] == `FP16_SNAN; })
        
        // Case 4: -sNan
        `uvm_do_special_case("req_n_snan", req, { req.inputs[0] == `FP16_N_SNAN; })

        // Case 5: qNaN
        `uvm_do_special_case("req_p_qnan", req, { req.inputs[0] == `FP16_QNAN; })
        
        // Case 6: -qNaN
        `uvm_do_special_case("req_n_qnan", req, { req.inputs[0] == `FP16_N_QNAN; })

        // Case 7: +Inf
        `uvm_do_special_case("req_p_inf", req, { req.inputs[0] == `FP16_P_INF; })
        
        // Case 8: -Inf
        `uvm_do_special_case("req_n_inf", req, { req.inputs[0] == `FP16_N_INF; })
        
        // Case 9: +0
        `uvm_do_special_case("req_p_zero", req, { req.inputs[0] == `FP16_P_ZERO; })
        
        // Case 10: -0
        `uvm_do_special_case("req_n_zero", req, { req.inputs[0] == `FP16_N_ZERO; })
        
        // Case 11: Denormal
        `uvm_do_special_case("req_p_denormal", req, { req.inputs[0] == 16'h0001; })
        
        // Case 12: -Denormal
        `uvm_do_special_case("req_n_denormal", req, { req.inputs[0] == 16'h8001; })

        `uvm_info("SEQ", "Finished special cases sequence", UVM_LOW)

    endtask

endclass
