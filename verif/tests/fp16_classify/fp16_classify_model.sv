// verif/tests/fp16_classify/fp16_classify_model.sv
// Reference model for the fp16_classify operation.
// This model uses a "golden" C function via the DPI-C interface,
// ensuring it is a trusted, independent reference.

`include "uvm_macros.svh"

// Import the C function. The name must match the C source.
// The return and argument types must match the data types in C.
// 'shortint' in SV is a 16-bit signed integer, which corresponds to
// 'uint16_t' in C for bit-pattern passing.

// DPI-C import of the C reference function
import "DPI-C" context function void c_fp16_classify(
    input  shortint                in,    // C uint16_t maps to SV shortint
    output fp16_classify_outputs_s out_s  // C struct* maps to SV output struct
);

class fp16_classify_model extends fp_model_base #(fp16_classify_transaction);
    `uvm_object_utils(fp16_classify_model)

    function new(string name="fp16_classify_model");
        super.new(name);
    endfunction

    // The predict function is extremely simple as a wrapper over C implementation.
    virtual function void predict(fp16_classify_transaction trans_in, ref fp16_classify_transaction trans_out);
        trans_out = new trans_in;
        // Call the imported C function to get the golden result
        c_fp16_classify(trans_in.inputs[0], trans_out.result);
    endfunction

endclass
