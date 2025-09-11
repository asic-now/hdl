// fp16_add_model.sv
// DUT-specific reference model.

`include "uvm_macros.svh"
import uvm_pkg::*;

class fp16_add_model extends fp_model_base #(fp16_add_transaction);
    `uvm_component_utils(fp16_add_model)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    // Implementation of the pure virtual function from the base class
    virtual function void calculate_golden(fp16_add_transaction tx);
        shortreal val_a, val_b, val_res;
        val_a = $bitstoshortreal({1'b0, tx.a});
        val_b = $bitstoshortreal({1'b0, tx.b});
        
        if (tx.a[15]) val_a = -val_a;
        if (tx.b[15]) val_b = -val_b;

        logic is_a_nan = (tx.a[14:10] == 5'h1F && tx.a[9:0] != 0);
        logic is_b_nan = (tx.b[14:10] == 5'h1F && tx.b[9:0] != 0);
        if (is_a_nan || is_b_nan) begin
            tx.golden_result = 16'h7C01; return;
        end
        
        logic is_a_inf = (tx.a[14:10] == 5'h1F && tx.a[9:0] == 0);
        logic is_b_inf = (tx.b[14:10] == 5'h1F && tx.b[9:0] == 0);
        if(is_a_inf && is_b_inf && (tx.a[15] != tx.b[15])) begin
             tx.golden_result = 16'h7C01; return;
        end
        
        val_res = val_a + val_b;
        
        logic signed_bit = (val_res < 0);
        if(signed_bit) val_res = -val_res;
        
        tx.golden_result = {signed_bit, $shortrealtobits(val_res)[14:0]};
    endfunction

endclass
