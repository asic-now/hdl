// verif/tests/fp16_add/fp16_add_model.sv
// Reference model for the fp16_add operation.
// This model uses a "golden" C function via the DPI-C interface,
// ensuring it is a trusted, independent reference.

`include "uvm_macros.svh"

// Import the C function. The name must match the C source.
// The return and argument types must match the data types in C.
// 'shortint' in SV is a 16-bit signed integer, which corresponds to
// 'uint16_t' in C for bit-pattern passing.
import "DPI-C" function shortint c_fp16_add(input shortint a, input shortint b);

class fp16_add_model extends fp_model_base #(fp16_transaction2);
    `uvm_object_utils(fp16_add_model)

    function new(string name="fp16_add_model");
        super.new(name);
    endfunction

    // The predict function is extremely simple as a wrapper over C implementation.
    virtual function void predict(fp16_transaction2 trans_in, ref fp16_transaction2 trans_out);
        trans_out = new trans_in;
        // Call the imported C function to get the golden result
        trans_out.result = c_fp16_add(trans_in.inputs[0], trans_in.inputs[1]);
    endfunction

endclass
