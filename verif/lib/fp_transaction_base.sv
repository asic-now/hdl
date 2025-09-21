// verif/lib/fp_transaction_base.sv
// Generic, parameterized base class for all floating-point transactions.
// It is parameterized by data WIDTH and the number of inputs (NUM_INPUTS).

`include "uvm_macros.svh"
import uvm_pkg::*;

virtual class fp_transaction_base #(
    int WIDTH = 16,
    int NUM_INPUTS = 2
) extends uvm_sequence_item;

    // --- Data Fields ---
    rand logic [WIDTH-1:0] inputs[]; // Dynamic array
    logic [WIDTH-1:0] result;

    // Constructor
    function new(string name = "fp_transaction_base");
        super.new(name);
        // Allocate the dynamic array
        inputs = new[NUM_INPUTS];
    endfunction

    // Pure virtual function to ensure subclasses implement it
    // pure virtual function string convert2string();

endclass
