// rtl/verilog/lib/fas_vec.v
// full_add_sub (parameterized WIDTH-bit)

module fas_vec #(parameter WIDTH = 8) (
    input  wire [WIDTH-1:0] a,
    input  wire [WIDTH-1:0] b,
    input  wire cin,
    input  wire add_nsub,       // 0: add, 1: subtract
    output wire [WIDTH-1:0] z,
    output wire cout
);
    wire [WIDTH-1:0] cout_add_vect;
    wire [WIDTH-1:0] cout_sub_vect;
    wire [WIDTH:0] c_add;
    wire [WIDTH:0] c_sub;

    assign c_add[0] = cin;
    assign c_sub[0] = cin;

    // Can't use array of instances here (it was introduced in SystemVerilog, but not in pure Verilog)
    genvar i;
    generate
        for (i = 0; i < WIDTH; i = i + 1) begin : fas_gen
            fas fas_unit (
                .a(a[i]),
                .b(b[i]),
                .cin(add_nsub ? c_sub[i] : c_add[i]), // select carry/borrow in
                .z(z[i]),
                .cout_add(cout_add_vect[i]),
                .cout_sub(cout_sub_vect[i])
            );
            assign c_add[i+1] = cout_add_vect[i];
            assign c_sub[i+1] = cout_sub_vect[i];
        end
    endgenerate

    assign cout = add_nsub ? c_sub[WIDTH] : c_add[WIDTH];
endmodule
