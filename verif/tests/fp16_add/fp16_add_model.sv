// fp16_add_model.sv
// Reference model for the fp16_add operation.

`include "uvm_macros.svh"
import uvm_pkg::*;

class fp16_add_model extends fp_model_base #(fp16_add_transaction);
    `uvm_object_utils(fp16_add_model)

    function new(string name="fp16_add_model");
        super.new(name);
    endfunction

    // Function to convert 16-bit half-precision to shortreal
    function shortreal fp16_to_shortreal(logic [15:0] fp16);
        logic sign;
        logic [4:0] exp;
        logic [9:0] mant;
        logic [31:0] fp32;

        sign = fp16[15];
        exp  = fp16[14:10];
        mant = fp16[9:0];

        if (exp == 5'h1F) begin // NaN or Inf
            fp32 = {sign, 8'hFF, mant[9], 22'b0}; // Propagate MSB of mant for NaN
        end else if (exp == 0) begin // Zero or Denormal
            fp32 = {sign, 31'b0}; // Treat denormals as zero for simplicity
        end else begin // Normal number
            logic [7:0] new_exp;
            new_exp = exp - 15 + 127;
            fp32 = {sign, new_exp, mant, 13'b0};
        end
        return $bitstoshortreal(fp32);
    endfunction

    // Function to convert shortreal back to 16-bit half-precision (simplified)
    function logic [15:0] shortreal_to_fp16(shortreal val);
        // This is a simplified conversion and might not handle all corner cases.
        // For a full UVM environment, a more robust DPI-C function is often used.
        logic [31:0] fp32;
        logic sign;
        logic [7:0] exp32;
        logic [22:0] mant32;
        logic [4:0] exp16;
        logic [9:0] mant16;

        fp32 = $shortrealtobits(val);
        sign = fp32[31];
        exp32 = fp32[30:23];
        mant32 = fp32[22:0];

        if (exp32 == 8'hFF) begin // Inf or NaN
            exp16 = 5'h1F;
            mant16 = {mant32[22], 9'b0};
        end else if (exp32 < (127 - 14)) begin // Underflow to zero
            exp16 = 5'b0;
            mant16 = 10'b0;
        end else if (exp32 > (127 + 15)) begin // Overflow to Inf
            exp16 = 5'h1F;
            mant16 = 10'b0;
        end else begin
            exp16 = exp32 - 127 + 15;
            mant16 = mant32[22:13];
        end
        return {sign, exp16, mant16};
    endfunction

    // Implementation of the pure virtual function from the base class
    virtual function void predict(fp16_add_transaction trans_in, ref fp16_add_transaction trans_out);
        shortreal r_a, r_b, r_result;

        // Convert inputs to shortreal for calculation
        r_a = fp16_to_shortreal(trans_in.a);
        r_b = fp16_to_shortreal(trans_in.b);
        
        // Perform the addition
        r_result = r_a + r_b;

        // Copy original inputs and set the predicted result
        trans_out = new trans_in;
        trans_out.result = shortreal_to_fp16(r_result);
    endfunction

endclass
