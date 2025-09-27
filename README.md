# hdl

Hardware Description Language library

This project contains a library of synthesizable Verilog RTL for various floating-point operations, along with a comprehensive UVM-based verification environment.

It is WIP (Work In Progress), and not everything has been verified.

## Floating Point Numbers - IEEE 754

[IEEE-754 floating point numbers converter](https://numeral-systems.com/ieee-754-converter/)

## Project Structure

The repository is organized into two main directories: rtl/ and verif/.

* rtl/verilog/: Contains all synthesizable Verilog source code.  
  * fp16/: Modules for 16-bit (half-precision) floating-point numbers.  
  * fp32/: Modules for 32-bit (single-precision) floating-point numbers.  
  * fp64/: Modules for 64-bit (double-precision) floating-point numbers.  
* verif/: Contains the UVM verification environment.  
  * lib/: Contains generic, reusable UVM base classes and components designed to be shared across different testbenches.  
  * tests/: Contains DUT-specific testbenches. Each subdirectory (e.g., fp16\_add/) is a complete testbench for a single RTL module.

## Design Conventions

To ensure consistency and synthesizability, all RTL modules in this project must adhere to the following conventions.

### Reset Strategy

The project employs an **asynchronous, active-low reset**.

* **Signal Name**: The reset signal must be named `rst_n`.
* **Implementation**: All sequential elements (flip-flops) must be sensitive to the low level of `rst_n` and reset to a known, stable state.
* **Synchronization**: Synchronization of reset rising edge to the clock is delegated to the users of this library.

Example of a resettable register:

```verilog
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        my_register <= 'd0;
    end else begin
        my_register <= next_value;
    end
end
```

## Implementation Specifics

Verification in testbenches is simplified:

* Sign of NaN is not preserved.
* sNaN and qNaN, -NaN and +NaN differences are ignored.
* Results precision fitting is done by truncation, not rounding.
* -0 may be used instead of +0.

## Tooling

For simulator setup and other tools see [TOOLING.md](TOOLING.md)

## Readiness Status

The table below shows the implementation and verification status of the floating-point modules.

| Operation     | fp16          | fp32       | fp64       |
|---------------|---------------|------------|------------|
| `add`         | [x]  Verified | RTL only   | RTL only   |
| `classify`    | [x]  Verified | RTL only   | RTL only   |
| `cmp`         | RTL only      | RTL only   | RTL only   |
| `div`         | RTL only      | RTL only   | RTL only   |
| `invsqrt`     | RTL only      | RTL only   | RTL only   |
| `mul`         | RTL only      | RTL only   | RTL only   |
| `mul_add`     | RTL only      | RTL only   | RTL only   |
| `mul_sub`     | RTL only      | RTL only   | RTL only   |
| `recip`       | RTL only      | RTL only   | RTL only   |
| `sqrt`        | RTL only      | RTL only   | RTL only   |
| `to_int`      | RTL only      | RTL only   | RTL only   |
| `from_int`    | RTL only      | RTL only   | RTL only   |
| `to_fp16`     | -             | RTL only   | RTL only   |
| `to_fp32`     | RTL only      | -          | RTL only   |
| `to_fp64`     | -             | RTL only   | -          |
