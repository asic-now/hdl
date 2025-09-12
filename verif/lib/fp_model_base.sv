// fp_model_base.sv
// Generic base class for a reference model.

`include "uvm_macros.svh"
import uvm_pkg::*;

virtual class fp_model_base #(type T = uvm_sequence_item) extends uvm_object;
    // `uvm_object_utils(fp_model_base #(T))


    // This is a pure virtual function. Any class that extends this base
    // MUST implement a function with this exact signature.
    pure virtual function void predict(T trans_in, ref T trans_out);

    // Standard constructor for a uvm_object
    function new(string name="fp_model_base");
        super.new(name);
    endfunction

endclass
