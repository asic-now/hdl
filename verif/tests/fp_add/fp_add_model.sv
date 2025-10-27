// verif/tests/fp_add/fp_add_model.sv
// Reference model for the fp_add operation.
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
import "DPI-C" function shortint unsigned c_fp16_add(shortint unsigned a, shortint unsigned b);
import "DPI-C" function int unsigned      c_fp32_add(int      unsigned a, int unsigned b);
import "DPI-C" function longint unsigned  c_fp64_add(longint  unsigned a, longint unsigned b);

class fp_add_model #(
    parameter int WIDTH = 16
) extends fp_model_base #(fp_transaction2 #(WIDTH));

    `uvm_object_param_utils(fp_add_model #(WIDTH))

    function new(string name="fp_add_model");
        super.new(name);
    endfunction

    // The predict function is extremely simple as a wrapper over C implementation.
    virtual function void predict(fp_transaction2 #(WIDTH) trans_in, ref fp_transaction2 #(WIDTH) trans_out);
        trans_out = new trans_in;
        // Call the imported C function to get the golden result
        case (WIDTH)
            16: trans_out.result = c_fp16_add(trans_in.inputs[0], trans_in.inputs[1]);
            32: trans_out.result = c_fp32_add(trans_in.inputs[0], trans_in.inputs[1]);
            64: trans_out.result = c_fp64_add(trans_in.inputs[0], trans_in.inputs[1]);
            default: `uvm_fatal("MODEL", $sformatf("Unsupported WIDTH %0d", WIDTH))
        endcase
    endfunction

endclass
