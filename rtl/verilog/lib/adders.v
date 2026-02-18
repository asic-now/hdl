// rtl/verilog/lib/adders.v
// (WIP) Various optimixed full adder circuits
// fas_vec_cla #(parameter WIDTH = 8) (
// fas_vec_carry_skip #(parameter WIDTH=8, parameter BLOCK_SIZE=4) (
// fas_vec_carry_select #(parameter WIDTH=8, parameter BLOCK_SIZE=4) (
// fas_vec_prefix #(parameter WIDTH=8) (
// fa_vec_carry_save #(parameter WIDTH=8) (
//     input wire [WIDTH-1:0] a, b, c,
//     output wire [WIDTH-1:0] z,
//     input  wire add_nsub,       // 0: add, 1: subtract // TODO: (now) Implement subtraction
//     output wire [WIDTH-1:0] carry)

// Basic 1-bit full adder
module fa (
    input  wire a, b, cin,
    output wire z, cout
);
    assign z = a ^ b ^ cin;
    assign cout = (a & b) | (b & cin) | (a & cin);
endmodule

// Carry Lookahead Adder (CLA) (Basic implementation)
module fas_vec_cla #(parameter WIDTH = 8) (
    input wire [WIDTH-1:0] a, b,
    input wire cin,
    input  wire add_nsub,       // 0: add, 1: subtract
    output wire [WIDTH-1:0] z,
    output wire cout
);
    wire [WIDTH-1:0] p, g; // propagate and generate
    wire [WIDTH:0] c;
    assign c[0] = cin ^ add_nsub;

    genvar i;

    wire [WIDTH-1:0] b_eff;
    generate
        for (i=0; i < WIDTH; i=i+1) begin : cla_b_eff
            assign b_eff[i] = b[i] ^ add_nsub;
        end
    endgenerate

    generate
        for (i=0; i < WIDTH; i=i+1) begin : cla_bits
            assign p[i] = a[i] ^ b_eff[i];
            assign g[i] = a[i] & b_eff[i];
        end
    endgenerate

    // Carry lookahead logic (simple recursive)
    generate
        for (i=0; i < WIDTH; i=i+1) begin : carry_gen
            assign c[i+1] = g[i] | (p[i] & c[i]);
        end
    endgenerate

    generate
        for (i=0; i < WIDTH; i=i+1) begin : sum_gen
            assign z[i] = a[i] ^ b_eff[i] ^ c[i];
        end
    endgenerate

    assign cout = c[WIDTH] ^ add_nsub;
endmodule

// Carry Skip Adder (CSA) (Group skip blocks, basic implementation)
module fas_vec_carry_skip #(parameter WIDTH=8, parameter BLOCK_SIZE=4) (
    input wire [WIDTH-1:0] a, b,
    input wire cin,
    input  wire add_nsub,       // 0: add, 1: subtract
    output wire [WIDTH-1:0] z,
    output wire cout
);
    wire [WIDTH:0] c;
    wire [WIDTH-1:0] p, g;
    wire [WIDTH/BLOCK_SIZE-1:0] block_skip;
    wire [WIDTH-1:0] b_eff;

    assign c[0] = cin ^ add_nsub;

    genvar i;
    generate
        for (i=0; i < WIDTH; i=i+1) begin : csa_b_eff
            assign b_eff[i] = b[i] ^ add_nsub;
        end
    endgenerate

    generate
        for (i=0; i < WIDTH; i=i+1) begin : bits
            assign p[i] = a[i] ^ b_eff[i];
            assign g[i] = a[i] & b_eff[i];
        end
    endgenerate

    // Ripple adder within blocks
    genvar j;
    generate
        for (j=0; j < WIDTH; j=j+1) begin : block_adder
            if (j == 0)
                assign c[j+1] = g[j] | (p[j] & c[j]);
            else
                assign c[j+1] = g[j] | (p[j] & c[j]);
        end
    endgenerate

    // Block propagate = AND of all propagates in the block
    wire [WIDTH/BLOCK_SIZE-1:0] block_propagate;
    genvar k;
    generate
        for (k=0; k < WIDTH/BLOCK_SIZE; k=k+1) begin : block_propagate_gen
            wire block_p = &p[(k*BLOCK_SIZE) +: BLOCK_SIZE];
            assign block_propagate[k] = block_p;
        end
    endgenerate

    // Block carry skip logic
    generate
        for (k=0; k < WIDTH/BLOCK_SIZE; k=k+1) begin : skip_logic
            if (k == 0)
                assign c[(k+1)*BLOCK_SIZE] = g[(k*BLOCK_SIZE) + BLOCK_SIZE -1] |
                                            (p[(k*BLOCK_SIZE) + BLOCK_SIZE -1] & c[k*BLOCK_SIZE]);
            else
                assign c[(k+1)*BLOCK_SIZE] = block_propagate[k-1] ? 
                                            c[k*BLOCK_SIZE] : c[(k*BLOCK_SIZE)];
        end
    endgenerate

    generate
        for (i=0; i < WIDTH; i=i+1) begin : sum_gen
            assign z[i] = a[i] ^ b_eff[i] ^ c[i];
        end
    endgenerate

    assign cout = c[WIDTH] ^ add_nsub;
endmodule

// Carry Select Adder (CSelA) (Dual blocks for carry 0 and 1)
module fas_vec_carry_select #(parameter WIDTH=8, parameter BLOCK_SIZE=4) (
    input wire [WIDTH-1:0] a, b,
    input wire cin,
    input  wire add_nsub,       // 0: add, 1: subtract
    output wire [WIDTH-1:0] z,
    output wire cout
);
    wire [WIDTH-1:0] b_eff;
    wire [WIDTH:0] cin_arr;
    wire [WIDTH-1:0] sum0, sum1;
    wire [WIDTH-1:0] carry0, carry1;

    genvar i;
    generate
        for (i=0; i < WIDTH; i=i+1) begin : csel_b_eff
            assign b_eff[i] = b[i] ^ add_nsub;
        end
    endgenerate

    assign cin_arr[0] = cin ^ add_nsub;

    generate
        for (i=0; i < WIDTH; i=i+1) begin : bits
            wire carry_in = cin_arr[i];
            fa fa0 (.a(a[i]), .b(b_eff[i]), .cin(1'b0), .z(sum0[i]), .cout(carry0[i]));
            fa fa1 (.a(a[i]), .b(b_eff[i]), .cin(1'b1), .z(sum1[i]), .cout(carry1[i]));
            assign z[i] = carry_in ? sum1[i] : sum0[i];
            assign cin_arr[i+1] = carry_in ? carry1[i] : carry0[i];
        end
    endgenerate
    assign cout = cin_arr[WIDTH] ^ add_nsub;
endmodule

// Prefix Adder (Kogge-Stone simplified example)
module fas_vec_prefix #(parameter WIDTH=8) (
    input wire [WIDTH-1:0] a, b,
    input wire cin,
    input  wire add_nsub,       // 0: add, 1: subtract
    output wire [WIDTH-1:0] z,
    output wire cout
);
    wire [WIDTH-1:0] b_eff;
    wire [WIDTH-1:0] p, g;
    wire [WIDTH:0] c;
    assign c[0] = cin ^ add_nsub;

    genvar i;
    generate
        for(i=0; i<WIDTH; i=i+1) begin : prefix_b_eff
            assign b_eff[i] = b[i] ^ add_nsub;
        end
    endgenerate
    generate
        for(i=0; i<WIDTH; i=i+1) begin : pg
            assign p[i] = a[i] ^ b_eff[i];
            assign g[i] = a[i] & b_eff[i];
        end
    endgenerate

    // Prefix network (Kogge-Stone simplified, log2)
    // Level-wise propagate and generate signals omitted for brevity
    // Here, doing simple carry ripple as placeholder
    generate
        for(i=0; i<WIDTH; i=i+1) begin : carry_calc
            assign c[i+1] = g[i] | (p[i] & c[i]);
        end
    endgenerate

    generate
        for(i=0; i<WIDTH; i=i+1) begin : sum_calc
            assign z[i] = p[i] ^ c[i];
        end
    endgenerate

    assign cout = c[WIDTH] ^ add_nsub;
endmodule

// Carry Save Adder (CSA) - For multi-operand addition (example 3 operands)
module fa_vec_carry_save #(parameter WIDTH=8) (
    input wire [WIDTH-1:0] a, b, c,
    output wire [WIDTH-1:0] z,
    input  wire add_nsub,       // 0: add, 1: subtract
    output wire [WIDTH-1:0] carry
);
    genvar i;
    generate
        for (i=0; i < WIDTH; i=i+1) begin : csa_bits
            assign z[i] = a[i] ^ b[i] ^ c[i];
            assign carry[i] = (a[i] & b[i]) | (b[i] & c[i]) | (a[i] & c[i]);
        end
    endgenerate
endmodule

// Manchester Carry Chain Adder (conceptual)
// Implementation requires transistor-level or special dynamic logic,
// omitted here due to complexity beyond simple RTL model.
