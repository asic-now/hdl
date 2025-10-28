// verif/lib/fp_pkg_utils.sv
// This file is included in fp_lib_pkg.sv
// It contains various package-scoped utility functions for floating-point manipulation.

`include "uvm_macros.svh"
import fp_dpi_pkg::*; // Import DPI-C functions for real conversions

// Returns the exponent width for a given total bit width.
function int unsigned get_exp_width(int unsigned width);
    case (width)
        16: return 5;
        32: return 8;
        64: return 11;
        default: begin
            `uvm_fatal("FP_PKG_UTILS", $sformatf("Unsupported WIDTH %0d in get_exp_width", width));
            return 0;
        end
    endcase
endfunction

// Returns the mantissa width for a given total bit width.
function int unsigned get_mant_width(int unsigned width);
    case (width)
        16: return 10;
        32: return 23;
        64: return 52;
        default: begin
            `uvm_fatal("FP_PKG_UTILS", $sformatf("Unsupported WIDTH %0d in get_mant_width", width));
            return 0;
        end
    endcase
endfunction

// Converts a real number to its floating-point bit representation.
function logic [63:0] float_to_fp(real val, int unsigned width);
    case (width)
        16: return c_real_to_fp16_bits(val);
        32: return $realtobits(val); // Standard SystemVerilog function for real to 32-bit float bits
        64: return c_real_to_fp64_bits(val);
        default: begin
            `uvm_fatal("FP_PKG_UTILS", $sformatf("Unsupported WIDTH %0d in float_to_fp", width));
            return 'x;
        end
    endcase
endfunction

// --- Functions to generate special FP values ---

function logic [63:0] get_p_zero(int unsigned width);
    return 0;
endfunction

function logic [63:0] get_n_zero(int unsigned width);
    logic [63:0] n_zero;
    n_zero = 0;
    n_zero[width-1] = 1;
    return n_zero;
endfunction

function logic [63:0] get_p_inf(int unsigned width);
    logic [63:0] p_inf;
    p_inf = 0;
    case (width)
        16: p_inf[14 -: 5] = '1;
        32: p_inf[30 -: 8] = '1;
        64: p_inf[62 -: 11] = '1;
        default: begin
            `uvm_fatal("FP_PKG_UTILS", $sformatf("Unsupported WIDTH %0d in get_p_inf", width));
            return 'x;
        end
    endcase
    return p_inf;
endfunction

function logic [63:0] get_n_inf(int unsigned width);
    logic [63:0] n_inf;
    n_inf = 0;
    n_inf[width-1] = 1;
    case (width)
        16: n_inf[14 -: 5] = '1;
        32: n_inf[30 -: 8] = '1;
        64: n_inf[62 -: 11] = '1;
        default: begin
            `uvm_fatal("FP_PKG_UTILS", $sformatf("Unsupported WIDTH %0d in get_n_inf", width));
            return 'x;
        end
    endcase
    return n_inf;
endfunction

function logic [63:0] get_qnan(int unsigned width);
    logic [63:0] qnan;
    qnan = 0;
    case (width)
        16: begin
            qnan[14 -: 5] = '1;
            qnan[9] = 1; // MSB of mantissa for FP16
        end
        32: begin
            qnan[30 -: 8] = '1;
            qnan[22] = 1; // MSB of mantissa for FP32
        end
        64: begin
            qnan[62 -: 11] = '1;
            qnan[51] = 1; // MSB of mantissa for FP64
        end
        default: begin
            `uvm_fatal("FP_PKG_UTILS", $sformatf("Unsupported WIDTH %0d in get_qnan", width));
            return 'x;
        end
    endcase
    return qnan;
endfunction

function logic [63:0] get_n_qnan(int unsigned width);
    logic [63:0] qnan;
    qnan = get_qnan(width);
    qnan[width-1] = 1;
    return qnan;
endfunction

function logic [63:0] get_snan(int unsigned width);
    logic [63:0] snan;
    snan = 0;
    case (width)
        16: snan[14 -: 5] = '1;
        32: snan[30 -: 8] = '1;
        64: snan[62 -: 11] = '1;
        default: begin
            `uvm_fatal("FP_PKG_UTILS", $sformatf("Unsupported WIDTH %0d in get_snan", width));
            return 'x;
        end
    endcase
    // Mantissa is non-zero, and MSB is 0 for SNaN
    snan[0] = 1;
    return snan;
endfunction

function logic [63:0] get_n_snan(int unsigned width);
    logic [63:0] snan;
    snan = get_snan(width);
    snan[width-1] = 1;
    return snan;
endfunction

function logic [63:0] get_denormal(int unsigned width);
    logic [63:0] denormal;
    denormal = 0;
    // For a denormal number, the exponent is all zeros and the mantissa is non-zero.
    // We'll create the smallest positive denormal number by setting the LSB of the mantissa.
    denormal[0] = 1;
    return denormal;
endfunction

function logic [63:0] get_n_denormal(int unsigned width);
    logic [63:0] denormal;
    denormal = get_denormal(width);
    denormal[width-1] = 1;
    return denormal;
endfunction
