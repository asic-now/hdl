# FP16 Floating-Point Library Modules

This directory contains synthesizable Verilog RTL for 16-bit (half-precision) floating-point operations.

* (fp16_add.v: moved to parameterized ../fp/fp_add.v)
* (fp16_classify.v: moved to parameterized ../fp/fp_classify.v)
* fp16_cmp.v
* fp16_div.v
* fp16_invsqrt.v
* fp16_mul_add.v
* fp16_mul_sub.v
* fp16_mul.v
* fp16_recip.v
* fp16_sqrt.v
* fp32_to_fp16.v
* fp16_to_int16.v
* int16_to_fp16.v

## Format (IEEE 754 half-precision)

```text
  [   15]: Sign bit (1 for negative, 0 for positive)
  [14:10]: 5-bit exponent (bias of 15)
  [ 9: 0]: 10-bit mantissa (fraction/significand)
```

$f = (-1)^{\text{val}[15]} \cdot 2^{(\text{val}[14:10] - 15)} \cdot \frac{(2^{10} + \text{val}[9:0])}{2^{10}}$

`f = (-1) ^ val[15] * 2 ^ (val[14:10] - 15) * ((1<<10) + val[9:0]) / (1<<10)`
