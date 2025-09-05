// fp_transaction_base.sv
// Base class for all floating-point transactions.
// It provides common fields that the generic scoreboard will use.

`include "uvm_macros.svh"
import uvm_pkg::*;

virtual class fp_transaction_base extends uvm_sequence_item;

    // Data fields common to all operations
    logic [63:0] result;
    logic [63:0] golden_result;

    // Constructor
    function new(string name = "fp_transaction_base");
        super.new(name);
    endfunction

    // Pure virtual function to ensure subclasses implement it
    pure virtual function string convert2string();

endclass
