// fp16_add_special_cases_sequence.sv
//
// A directed sequence that generates transactions to test all known
// special cases for floating-point addition (NaN, Inf, Zero).

`include "uvm_macros.svh"

`include "fp16_inc.vh"

class fp16_add_special_cases_sequence extends uvm_sequence #(fp16_add_transaction);
    `uvm_object_utils(fp16_add_special_cases_sequence)

    function new(string name="fp16_add_special_cases_sequence");
        super.new(name);
    endfunction

    virtual task body();
        fp16_add_transaction req;
        
        `uvm_info("SEQ", "Starting special cases sequence", UVM_LOW)

        // Case 1: sNaN + Normal -> qNaN
        req = fp16_add_transaction::type_id::create("req_snan_1");
        start_item(req);
        req.a = `FP16_SNAN; // sNaN
        req.b = 16'h3C00; // 1.0
        finish_item(req);

        // Case 2: Normal + sNaN -> qNaN
        req = fp16_add_transaction::type_id::create("req_snan_2");
        start_item(req);
        req.a = 16'h3C00; // 1.0
        req.b = `FP16_SNAN; // sNaN
        finish_item(req);

        // Case 3: -sNan + Normal -> -qNaN
        req = fp16_add_transaction::type_id::create("req_snan_3");
        start_item(req);
        req.a = `FP16_N_SNAN; // -sNaN
        req.b = 16'h4000; // 2.0
        finish_item(req);

        // Case 4: Normal + -sNan -> -qNaN
        req = fp16_add_transaction::type_id::create("req_snan_4");
        start_item(req);
        req.a = 16'h4000; // 2.0
        req.b = `FP16_N_SNAN; // -sNaN
        finish_item(req);

        // Case 5: qNaN + Normal -> qNaN
        req = fp16_add_transaction::type_id::create("req_qnan_1");
        start_item(req);
        req.a = `FP16_QNAN; // -qNaN
        req.b = 16'h3C00; // 1.0
        finish_item(req);

        // Case 6: Normal + qNaN -> qNaN
        req = fp16_add_transaction::type_id::create("req_qnan_2");
        start_item(req);
        req.a = 16'h3C00; // 1.0
        req.b = `FP16_QNAN; // -qNaN
        finish_item(req);

        // Case 7: -qNaN + Normal -> -qNaN
        req = fp16_add_transaction::type_id::create("req_qnan_3");
        start_item(req);
        req.a = `FP16_N_QNAN; // -qNaN
        req.b = 16'h4000; // 2.0
        finish_item(req);

        // Case 8: Normal + -qNaN -> -qNaN
        req = fp16_add_transaction::type_id::create("req_qnan_4");
        start_item(req);
        req.a = 16'h4000; // 2.0
        req.b = `FP16_N_QNAN; // -qNaN
        finish_item(req);

        // Case 9: +Inf + +Inf -> +Inf
        req = fp16_add_transaction::type_id::create("req_inf_1");
        start_item(req);
        req.a = `FP16_P_INF; // +Inf
        req.b = `FP16_P_INF; // +Inf
        finish_item(req);
        
        // Case 10: -Inf + -Inf -> -Inf
        req = fp16_add_transaction::type_id::create("req_inf_2");
        start_item(req);
        req.a = `FP16_N_INF; // -Inf
        req.b = `FP16_N_INF; // -Inf
        finish_item(req);

        // Case 11: +Inf + -Inf -> qNaN (Invalid operation)
        req = fp16_add_transaction::type_id::create("req_inf_3");
        start_item(req);
        req.a = `FP16_P_INF; // +Inf
        req.b = `FP16_N_INF; // -Inf
        finish_item(req);
        
        // Case 12: -Inf + +Inf -> qNaN (Invalid operation)
        req = fp16_add_transaction::type_id::create("req_inf_4");
        start_item(req);
        req.a = `FP16_N_INF; // -Inf
        req.b = `FP16_P_INF; // +Inf
        finish_item(req);
        
        // Case 13: +Inf + Normal -> +Inf
        req = fp16_add_transaction::type_id::create("req_inf_5");
        start_item(req);
        req.a = `FP16_P_INF; // +Inf
        req.b = 16'hC000; // -2.0
        finish_item(req);

        // Case 14: +0 + -0 -> +0
        req = fp16_add_transaction::type_id::create("req_zero_1");
        start_item(req);
        req.a = `FP16_P_ZERO; // +0
        req.b = `FP16_N_ZERO; // -0
        finish_item(req);
        
        // Case 15: -0 + -0 -> -0
        req = fp16_add_transaction::type_id::create("req_zero_2");
        start_item(req);
        req.a = `FP16_N_ZERO; // -0
        req.b = `FP16_N_ZERO; // -0
        finish_item(req);
        
        // Case 16: Normal + +0 -> Normal
        req = fp16_add_transaction::type_id::create("req_zero_3");
        start_item(req);
        req.a = 16'hC200; // -4.0
        req.b = `FP16_P_ZERO; // +0
        finish_item(req);

        `uvm_info("SEQ", "Finished special cases sequence", UVM_LOW)

    endtask

endclass
