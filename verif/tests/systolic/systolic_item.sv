// verif/tests/systolic/systolic_item.sv
// Parameterized UVM item for the systolic DUT.

`include "uvm_macros.svh"
import uvm_pkg::*;

class systolic_item #(
    parameter ROWS = 2,
    parameter COLS = 2,
    parameter WIDTH = 4,
    parameter ACC_WIDTH = 9
) extends uvm_sequence_item;

    rand bit [WIDTH-1:0] a_matrix [ROWS][ROWS];
    rand bit [WIDTH-1:0] b_matrix [ROWS][COLS];
    bit [ACC_WIDTH-1:0] c_matrix [ROWS][COLS];

    `uvm_object_param_utils(systolic_item #(ROWS, COLS, WIDTH, ACC_WIDTH))

    function new(string name = "systolic_item");
        super.new(name);
    endfunction

    // Helper to pack 2D array to 1D vector for DUT
    function logic [ROWS*ROWS*WIDTH-1:0] pack_a();
        logic [ROWS*ROWS*WIDTH-1:0] flat;
        for (int i = 0; i < ROWS; i++) begin
            for (int j = 0; j < ROWS; j++) begin
                flat[(i*ROWS + j)*WIDTH +: WIDTH] = a_matrix[i][j];
            end
        end
        return flat;
    endfunction

    function logic [ROWS*COLS*WIDTH-1:0] pack_b();
        logic [ROWS*COLS*WIDTH-1:0] flat;
        for (int i = 0; i < ROWS; i++) begin
            for (int j = 0; j < COLS; j++) begin
                flat[(i*COLS + j)*WIDTH +: WIDTH] = b_matrix[i][j];
            end
        end
        return flat;
    endfunction

    // Helper to unpack 1D vector from DUT to 2D array
    function void unpack_c(logic [ROWS*COLS*ACC_WIDTH-1:0] flat);
        for (int i = 0; i < ROWS; i++) begin
            for (int j = 0; j < COLS; j++) begin
                c_matrix[i][j] = flat[(i*COLS + j)*ACC_WIDTH +: ACC_WIDTH];
            end
        end
    endfunction

    function void unpack_a(logic [ROWS*ROWS*WIDTH-1:0] flat);
        for (int i = 0; i < ROWS; i++) begin
            for (int j = 0; j < ROWS; j++) begin
                a_matrix[i][j] = flat[(i*ROWS + j)*WIDTH +: WIDTH];
            end
        end
    endfunction

    function void unpack_b(logic [ROWS*COLS*WIDTH-1:0] flat);
        for (int i = 0; i < ROWS; i++) begin
            for (int j = 0; j < COLS; j++) begin
                b_matrix[i][j] = flat[(i*COLS + j)*WIDTH +: WIDTH];
            end
        end
    endfunction

    // Standard UVM methods implemented manually to avoid macro issues with 2D arrays
    function void do_copy(uvm_object rhs);
        systolic_item #(ROWS, COLS, WIDTH, ACC_WIDTH) rhs_;
        if (!$cast(rhs_, rhs)) begin
            `uvm_fatal("do_copy", "cast of rhs object failed")
        end
        super.do_copy(rhs);
        this.a_matrix = rhs_.a_matrix;
        this.b_matrix = rhs_.b_matrix;
        this.c_matrix = rhs_.c_matrix;
    endfunction

    function bit do_compare(uvm_object rhs, uvm_comparer comparer);
        systolic_item #(ROWS, COLS, WIDTH, ACC_WIDTH) rhs_;
        if (!$cast(rhs_, rhs)) return 0;
        return super.do_compare(rhs, comparer) &&
               (this.a_matrix == rhs_.a_matrix) &&
               (this.b_matrix == rhs_.b_matrix) &&
               (this.c_matrix == rhs_.c_matrix);
    endfunction

    function void do_print(uvm_printer printer);
        super.do_print(printer);
        foreach (a_matrix[i,j]) printer.print_int($sformatf("a_matrix[%0d][%0d]", i, j), a_matrix[i][j], WIDTH);
        foreach (b_matrix[i,j]) printer.print_int($sformatf("b_matrix[%0d][%0d]", i, j), b_matrix[i][j], WIDTH);
        foreach (c_matrix[i,j]) printer.print_int($sformatf("c_matrix[%0d][%0d]", i, j), c_matrix[i][j], ACC_WIDTH);
    endfunction

endclass
