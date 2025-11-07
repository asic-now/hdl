// verif/tests/fp_classify/fp_classify_model.sv
// Reference model for the fp_classify operation.
// This model uses a "golden" C function via the DPI-C interface,
// ensuring it is a trusted, independent reference.

`include "uvm_macros.svh"
import uvm_pkg::*;

// DPI-C imports of the C reference model functions.
// Note: The function names must match those in the C files.
// Use C-compatible integer types for DPI return values
// bit [15:0] : shortint unsigned : uint16_t
// bit [31:0] : int unsigned      : uint32_t
// bit [63:0] : longint unsigned  : uint64_t
// C struct* maps to SV output struct
import "DPI-C" context function void c_fp_classify(input longint  unsigned in, input int width, output fp_classify_outputs_s out_s);

class fp_classify_model #(
    parameter int WIDTH = 16
) extends fp_model_base #(fp_classify_transaction #(WIDTH));

    `uvm_object_param_utils(fp_classify_model #(WIDTH))

    function new(string name="fp_classify_model");
        super.new(name);
    endfunction

    // The predict function is extremely simple as a wrapper over C implementation.
    virtual function void predict(fp_classify_transaction #(WIDTH) trans_in, ref fp_classify_transaction #(WIDTH) trans_out);
        trans_out = new trans_in;
        // Call the imported C function to get the golden result
        c_fp_classify(trans_in.inputs[0], WIDTH, trans_out.result);
    endfunction

endclass
