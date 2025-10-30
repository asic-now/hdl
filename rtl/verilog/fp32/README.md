# FP32 Floating-Point Library Modules

This directory contains synthesizable Verilog RTL for 32-bit (single-precision) floating-point operations.

* (fp32_add.v: moved to parameterized ../fp/fp_add.v)
* (fp32_classify.v: moved to parameterized ../fp/fp_classify.v)
* fp32_cmp.v
* fp32_div.v
* fp32_invsqrt.v
* fp32_mul_add.v
* fp32_mul_sub.v
* (fp32_mul.v: moved to parameterized ../fp/fp_mul.v)
* fp32_recip.v
* fp32_sqrt.v
* fp32_to_int32.v
* fp32_to_fp16.v
* fp32_to_fp64.v
* int32_to_fp32.v

## Format (IEEE 754 single-precision)

```text
  [   31]: Sign bit (1 for negative, 0 for positive)
  [30:23]: 8-bit exponent (bias of 127)
  [22: 0]: 23-bit mantissa (fraction/significand)
```
