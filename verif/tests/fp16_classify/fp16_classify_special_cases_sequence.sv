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
        // TODO: (now) Use this macro everywhere below...

        // Case 1: Normal
        req = fp16_classify_transaction::type_id::create("req_p_norm");
        start_item(req);
        req.inputs[0] = 16'h3C00; // 1.0
        finish_item(req);

        // Case 2: -Normal
        req = fp16_classify_transaction::type_id::create("req_n_norm");
        start_item(req);
        req.inputs[0] = 16'hC000; // -2.0
        finish_item(req);

        // Case 3: sNaN
        req = fp16_classify_transaction::type_id::create("req_p_snan");
        start_item(req);
        req.inputs[0] = `FP16_SNAN;
        finish_item(req);

        // Case 4: -sNan
        req = fp16_classify_transaction::type_id::create("req_n_snan");
        start_item(req);
        req.inputs[0] = `FP16_N_SNAN;
        finish_item(req);

        // Case 5: qNaN
        req = fp16_classify_transaction::type_id::create("req_p_qnan");
        start_item(req);
        req.inputs[0] = `FP16_QNAN;
        finish_item(req);

        // Case 6: -qNaN
        req = fp16_classify_transaction::type_id::create("req_n_qnan");
        start_item(req);
        req.inputs[0] = `FP16_N_QNAN;
        finish_item(req);

        // Case 7: +Inf
        req = fp16_classify_transaction::type_id::create("req_p_inf");
        start_item(req);
        req.inputs[0] = `FP16_P_INF;
        finish_item(req);
        
        // Case 8: -Inf
        req = fp16_classify_transaction::type_id::create("req_n_inf");
        start_item(req);
        req.inputs[0] = `FP16_N_INF;
        finish_item(req);

        // Case 9: +0
        req = fp16_classify_transaction::type_id::create("req_p_zero");
        start_item(req);
        req.inputs[0] = `FP16_P_ZERO;
        finish_item(req);
        
        // Case 10: -0
        req = fp16_classify_transaction::type_id::create("req_n_zero");
        start_item(req);
        req.inputs[0] = `FP16_N_ZERO;
        finish_item(req);

        // Case 11: Denormal
        req = fp16_classify_transaction::type_id::create("req_p_denormal");
        start_item(req);
        req.inputs[0] = 16'h0001;
        finish_item(req);

        // Case 12: -Denormal
        req = fp16_classify_transaction::type_id::create("req_n_denormal");
        start_item(req);
        req.inputs[0] = 16'h8001;
        finish_item(req);

        `uvm_info("SEQ", "Finished special cases sequence", UVM_LOW)

    endtask

endclass
