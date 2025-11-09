// rtl/verilog/lib/fas.v
// full_add_sub (1-bit)

module fas (
    input  wire a,
    input  wire b,
    input  wire cin,        // carry or borrow in
    output wire z,          // sum/difference output
    output wire cout_add,   // carry out for addition
    output wire cout_sub    // borrow out for subtraction
);
/*
  Truth table:
  --------------------------------
  a  b  cin |  z cout_add cout_sub
  --------------------------------
  0  0  0   |  0 0        0
  0  0  1   |  1 0        1
  0  1  0   |  1 0        1
  0  1  1   |  0 0        1
  1  0  0   |  1 0        0
  1  0  1   |  0 0        0
  1  1  0   |  0 1        0
  1  1  1   |  1 1        0
  --------------------------------

*/

    // Sum/Difference bit is XOR of inputs
    assign z = a ^ b ^ cin;

    // Carry out for addition
    assign cout_add = (a & b) | (cin & (a ^ b));

    // Borrow out for subtraction:
    // borrow occurs if a < (b + cin)
    assign cout_sub = (~a & b) | ((~a ^ b) & cin);

endmodule
