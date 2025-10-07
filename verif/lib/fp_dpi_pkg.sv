// verif/lib/fp_dpi_pkg.sv
// DPI-C import package for floating-point utility functions.

package fp_dpi_pkg;

    // Use C-compatible integer types for DPI return values
    // bit [15:0] : shortint unsigned
    // bit [31:0] : int unsigned     
    // bit [63:0] : longint unsigned 
    import "DPI-C" function shortint unsigned c_real_to_fp16_bits(real val);
    import "DPI-C" function int unsigned      c_real_to_fp32_bits(real val);
    import "DPI-C" function longint unsigned  c_real_to_fp64_bits(real val);

endpackage