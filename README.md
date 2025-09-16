# hdl

Hardware Description Language library

This project contains a library of synthesizable Verilog RTL for various floating-point operations, along with a comprehensive UVM-based verification environment.

It is WIP (Work In Progress), and not everything has been verified.

## Floating Point Numbers - IEEE 754

<https://numeral-systems.com/ieee-754-converter/>

## Project Structure

The repository is organized into two main directories: rtl/ and verif/.

* rtl/verilog/: Contains all synthesizable Verilog source code.  
  * fp16/: Modules for 16-bit (half-precision) floating-point numbers.  
  * fp32/: Modules for 32-bit (single-precision) floating-point numbers.  
  * fp64/: Modules for 64-bit (double-precision) floating-point numbers.  
* verif/: Contains the UVM verification environment.  
  * lib/: Contains generic, reusable UVM base classes and components designed to be shared across different testbenches.  
  * tests/: Contains DUT-specific testbenches. Each subdirectory (e.g., fp16\_add/) is a complete testbench for a single RTL module.

## Tooling

For simulator setup and other tools see [TOOLING.md](TOOLING.md)
