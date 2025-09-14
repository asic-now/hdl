// fp16_add_special_cases_sequence.sv
//
// A directed sequence that generates transactions to test all known
// special cases for floating-point addition (NaN, Inf, Zero).

`include "uvm_macros.svh"

class fp16_add_special_cases_sequence extends uvm_sequence #(fp16_add_transaction);
    `uvm_object_utils(fp16_add_special_cases_sequence)

    function new(string name="fp16_add_special_cases_sequence");
        super.new(name);
    endfunction

    virtual task body();
        fp16_add_transaction req;
        
        `uvm_info("SEQ", "Starting special cases sequence", UVM_LOW)

        // Case 1: NaN + Normal -> NaN
        req = fp16_add_transaction::type_id::create("req_nan_1");
        start_item(req);
        req.a = 16'h7C01; // qNaN
        req.b = 16'h3C00; // 1.0
        finish_item(req);

        // Case 2: Normal + NaN -> NaN
        req = fp16_add_transaction::type_id::create("req_nan_2");
        start_item(req);
        req.a = 16'h4000; // 2.0
        req.b = 16'hFC01; // -qNaN
        finish_item(req);

        // Case 3: +Inf + +Inf -> +Inf
        req = fp16_add_transaction::type_id::create("req_inf_1");
        start_item(req);
        req.a = 16'h7C00; // +Inf
        req.b = 16'h7C00; // +Inf
        finish_item(req);
        
        // Case 4: -Inf + -Inf -> -Inf
        req = fp16_add_transaction::type_id::create("req_inf_2");
        start_item(req);
        req.a = 16'hFC00; // -Inf
        req.b = 16'hFC00; // -Inf
        finish_item(req);

        // Case 5: +Inf + -Inf -> NaN (Invalid operation)
        req = fp16_add_transaction::type_id::create("req_inf_3");
        start_item(req);
        req.a = 16'h7C00; // +Inf
        req.b = 16'hFC00; // -Inf
        finish_item(req);
        
        // Case 6: +Inf + Normal -> +Inf
        req = fp16_add_transaction::type_id::create("req_inf_4");
        start_item(req);
        req.a = 16'h7C00; // +Inf
        req.b = 16'hC000; // -2.0
        finish_item(req);

        // Case 7: +0 + -0 -> +0
        req = fp16_add_transaction::type_id::create("req_zero_1");
        start_item(req);
        req.a = 16'h0000; // +0
        req.b = 16'h8000; // -0
        finish_item(req);
        
        // Case 8: -0 + -0 -> -0
        req = fp16_add_transaction::type_id::create("req_zero_2");
        start_item(req);
        req.a = 16'h8000; // -0
        req.b = 16'h8000; // -0
        finish_item(req);
        
        // Case 9: Normal + +0 -> Normal
        req = fp16_add_transaction::type_id::create("req_zero_3");
        start_item(req);
        req.a = 16'hC200; // -4.0
        req.b = 16'h0000; // +0
        finish_item(req);

        `uvm_info("SEQ", "Finished special cases sequence", UVM_LOW)

    endtask

endclass
