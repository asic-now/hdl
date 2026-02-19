# HDL

Hardware Description Language library

This project contains a library of synthesizable Verilog RTL for various floating-point operations and matrix computations, along with a comprehensive UVM-based verification environment.

It is WIP (Work In Progress), and not everything has been verified.

## Floating Point Numbers - IEEE 754

[IEEE-754 floating point numbers converter](https://numeral-systems.com/ieee-754-converter/)

## Project Structure

The repository is organized into two main directories: rtl/ and verif/.

* rtl/verilog/: Contains all synthesizable Verilog source code.  
  * fp/: Parameterized modules for 16/32/64-bit floating-point numbers.  
  * fp16/: Modules for 16-bit (half-precision) floating-point numbers. In process of moving to parameterized version.  
  * fp32/: Modules for 32-bit (single-precision) floating-point numbers. In process of moving to parameterized version.  
  * fp64/: Modules for 64-bit (double-precision) floating-point numbers. In process of moving to parameterized version.  
  * systolic/: Parameterized Systolic Array.  
* verif/: Contains the UVM verification environment.  
  * lib/: Contains generic, reusable UVM base classes and components designed to be shared across different testbenches.  
  * tests/: Contains DUT-specific testbenches. Each subdirectory (e.g., fp\_add/) is a complete testbench for a single RTL module.

## RTL Design Conventions

To ensure consistency, readability, and synthesizability, all RTL modules in this library must adhere to the following conventions.

### Clocking and Reset Strategy

* **Clock Signal**: The primary clock signal must be named `clk`. All synchronous logic must be driven by the **positive edge** of this clock.
* **Reset Signal**: The project employs a global **asynchronous, active-low reset**. The reset signal must be named `rst_n`.

All sequential elements (flip-flops) must be sensitive to the `negedge rst_n` and initialize to a known, stable state. The de-assertion of the reset is assumed to be synchronous to `clk` by the instantiating module; this library does not implement a reset synchronizer internally.

#### **Example of a correctly clocked and reset register:**

```systemverilog
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        my_register <= 'd0;
    end else begin
        my_register <= my_register_next;
    end
end
```

### Logic Implementation Style

To prevent accidental latch inference and improve design clarity, a **two-process methodology** is required for all but the most trivial sequential logic. (Some existing cells might still have a mixed implementatioon, but they will be cleaned up eventually).

1. **Combinational Logic (`always_comb`)**: All combinational logic, including the calculation of the next state for registers, must be implemented in a dedicated `always_comb` block (or `always @(*)` for Verilog-2001).
2. **Sequential Logic (`always_ff`)**: The state-holding elements (flip-flops) must be implemented in a separate `always_ff` block (or `always @(posedge clk ...)` for Verilog-2001). This block should contain minimal logic and primarily perform non-blocking assignments from the next-state signals.

This separation clearly distinguishes between combinational paths and registered outputs, mirroring the physical hardware and making the design easier to debug and analyze.

#### **Example of the two-process style:**

```systemverilog
logic [7:0] my_counter_next;
logic [7:0] my_counter_q;

// Process 1: Combinational logic for next-state calculation
always_comb begin
    my_counter_next = my_counter_q + 1;
    if (clear_i) begin
        my_counter_next = 'd0;
    end
end

// Process 2: Sequential logic for state registration
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        my_counter_q <= 'd0;
    end
    else begin
        my_counter_q <= my_counter_next;
    end
end
```

### Signal Declarations and Naming

* **Declaration Location**: Declare signals as close as possible to their first use (typically right above the `always @()` blocks that drive them). This improves readability by keeping the logic and its associated signals in the same context.
* **Combined Declaration**: For combinational signals, it is strongly preferred to combine the `wire` (or `logic`) declaration with its continuous assignment.

```systemverilog
    // Preferred
    logic parity = a ^ b ^ c;

    // Not Preferred
    logic parity;
    assign parity = a ^ b ^ c;
```

* **Signal Naming Recommendation**:  
These are not strict requirements.
  * Use a `_next` or `_d` suffix for the combinational signal driving a register.
  * Use a `_q` suffix for the output of a register.
  * Use an `_i` suffix for module inputs and a `_o` suffix for module outputs.

### Parameterization

Modules should be made as generic as possible by using `parameter` for configurable values like data widths, vector sizes, or counter limits.

#### **SystemVerilog Example:**

```systemverilog
module my_module #(
    parameter int DATA_WIDTH = 32
) (
    input  logic                  clk,
    input  logic                  rst_n,
    input  logic [DATA_WIDTH-1:0] data_i,
    output logic [DATA_WIDTH-1:0] data_o
);

// ... module logic ...

endmodule
```

#### **Verilog Example:**

```verilog
module my_module #(
    parameter DATA_WIDTH = 32
) (
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire [DATA_WIDTH-1:0] data_i,
    output wire [DATA_WIDTH-1:0] data_o
);

// ... module logic ...

endmodule
```

## Implementation Specifics

Verification in testbenches is simplified:

* Sign of NaN is not preserved.
* sNaN and qNaN, -NaN and +NaN differences are ignored.
* -0 may be used instead of +0.

## Tooling

For simulator setup and other tools see [TOOLING.md](TOOLING.md)

## Readiness Status

The table below shows the implementation and verification status of the floating-point modules.

| Operation     | fp16          | fp32          | fp64          |
|---------------|---------------|---------------|---------------|
| `add`         | [x]  Verified | [x]  Verified | [x]  Verified |
| `classify`    | [x]  Verified | [x]  Verified | [x]  Verified |
| `cmp`         | RTL only      | RTL only      | RTL only      |
| `div`         | RTL only      | RTL only      | RTL only      |
| `invsqrt`     | RTL only      | RTL only      | RTL only      |
| `mul`         | [x]  Verified | [x]  Verified | [x]  Verified |
| `mul_add`     | RTL only      | RTL only      | RTL only      |
| `mul_sub`     | RTL only      | RTL only      | RTL only      |
| `recip`       | RTL only      | RTL only      | RTL only      |
| `sqrt`        | RTL only      | RTL only      | RTL only      |
| `to_int`      | RTL only      | RTL only      | RTL only      |
| `from_int`    | RTL only      | RTL only      | RTL only      |
| `to_fp16`     | -             | RTL only      | RTL only      |
| `to_fp32`     | RTL only      | -             | RTL only      |
| `to_fp64`     | -             | RTL only      | -             |

## Matrix Operations

| Operation     | Status        | Notes                                      |
|---------------|---------------|--------------------------------------------|
| `systolic`    | [x]  Verified | Parameterized integer systolic array (PE2) |
