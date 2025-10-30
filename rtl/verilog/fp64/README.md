# FP64 Floating-Point Library Modules

This directory contains synthesizable Verilog RTL for 64-bit (double-precision) floating-point operations.

* (fp64_add.v: moved to parameterized ../fp/fp_add.v)
* (fp64_classify.v: moved to parameterized ../fp/fp_classify.v)
* fp64_cmp.v
* fp64_div.v
* fp64_invsqrt.v
* fp64_mul_add.v
* fp64_mul_sub.v
* (fp64_mul.v: moved to parameterized ../fp/fp_mul.v)
* fp64_recip.v
* fp64_sqrt.v
* fp64_to_fp32.v
* fp64_to_int64.v
* int64_to_fp64.v

## Format (IEEE 754 double-precision)

```text
  [   63]: Sign bit (1 for negative, 0 for positive)
  [62:52]: 11-bit exponent (bias of 1023)
  [51: 0]: 52-bit mantissa (fraction/significand)
```
