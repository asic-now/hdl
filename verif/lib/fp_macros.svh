// verif/lib/fp_macros.svh
// This file contains custom, project-specific UVM macros to simplify
// testbench development.

`ifndef FP_MACROS_SVH
`define FP_MACROS_SVH

// `uvm_do_special_case(NAME, VAL_A, VAL_B)
//
// This new, more powerful macro handles the full boilerplate for a directed
// test case. It names the transaction, disables default constraints, applies
// the specified values, and re-enables the constraints.
//
// NAME: A string literal for the transaction's name.
// ITEM: The sequence item variable (e.g., req)
// CONSTRAINTS: An optional '{ ... }' block for use in `with` statement.
//
`define uvm_do_special_case(NAME, ITEM, CONSTRAINTS) \
  begin \
    // ITEM = fp16_transaction2::type_id::create(NAME); \
    ITEM = REQ::type_id::create(NAME); \
    // Disable the constraints before setting directed values \
    ITEM.category_dist_c.constraint_mode(0); \
    ITEM.values_c.constraint_mode(0); \
    start_item(ITEM); \
    if (!ITEM.randomize() with CONSTRAINTS) \
      `uvm_error("RND_FAIL", $sformatf("Randomization failed for %s", NAME)); \
    finish_item(ITEM); \
    ITEM.category_dist_c.constraint_mode(1); \
    ITEM.values_c.constraint_mode(1); \
  end

`endif // FP_MACROS_SVH
