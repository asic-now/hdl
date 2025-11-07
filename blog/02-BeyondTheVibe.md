# Beyond the Vibe: The Strategic Shift to Parameterized Design

Ilya I.  
2025-1106

![BeyondTheVibe](02-BeyondTheVibe.png)

In my previous post, "[Vibe Verilogging](01-VibeVerilogging.md)," I shared the initial rollercoaster ride of building an open-source floating-point library with Gemini. We celebrated a small victory: the `fp16_add` module, after considerable human intervention, finally passed its UVM regressions. It was a blueprint, a proof of concept, and a testament to the power of human-AI collaboration.

But a single `fp16_add` does not a floating-point library make. The initial plan was to simply replicate the `fp16_add` effort for `fp32` and `fp64`, and then do the same for multiplication, division, and so on. This brute-force approach felt inefficient and prone to error. It was time for a strategic pivot: moving from discrete precision-specific modules to a single, unified, parameterized implementation for each core function. This is where the human-AI dynamic was truly tested.

## The Perils of Native Models and the Shift to Bit-Accuracy

As I began parameterizing the RTL for `fp_add`, `fp_mul`, and `fp_classify`, the verification strategy had to evolve. First, UVM testbenches for each precision were almost identical, and unifying them with parameterization removed 3x copy-pasta. 

Next, my initial C models, verified against Python's NumPy, were a good start for `fp16`, but they had a hidden flaw. When I asked Gemini for ideas on a parameterized model, it consistently suggested using native floating-point functions in Python or C. This is a logical, high-level suggestion, but it's strategically wrong for rigorous RTL verification where internal precision and the IEEE rounding mode can be parameterized.

Why? Native implementations (like Python's `float` or NumPy's `float64`) are opaque and internally fixed. They rely on the host machine's FPU, which typically uses a single, fixed rounding mode (like Round to Nearest, Ties to Even). My RTL, however, needed to support *all* IEEE 754 rounding modes (RTZ, RPI, RNI, etc.) and allow for configurable internal precision to manage the trade-off between accuracy and resource usage. The AI's "easy" solution couldn't provide this level of control.

This was a critical strategic decision point where human experience overruled the AI's path of least resistance. I decided to build fully parameterized, **bit-accurate** models of `fp_add` and `fp_mul` from scratch in both Python (`fp_model.py`) and C (`fp_model.c`). These models perform every step of the floating-point operation—unpacking, alignment, addition/multiplication, normalization, and rounding—using pure integer arithmetic and bitwise operations. This gave me explicit control over exponent width, mantissa width, internal guard/round/sticky bits, and, most importantly, the rounding mode. It was a significant upfront investment, but it was the only way to create a truly reliable and configurable verification backbone.

## AI as a Language Bridge: Translating Intent, Not Just Syntax

Despite its struggles with semantic correctness in complex math, Gemini proved surprisingly adept at translating *intent* between programming languages, especially for boilerplate and interface code.

For instance, integrating the C golden models into the Python verification framework required `ctypes` bindings. Describing the C function signatures and asking Gemini to generate the corresponding Python `ctypes` calls was remarkably efficient. It understood the mapping of C types to Python `ctypes` and quickly produced functional wrappers.

```python
# Example of AI-assisted ctypes binding generation
libfp.c_fp_add.argtypes = [c_uint64, c_uint64, ctypes.c_int, ctypes.c_int]
libfp.c_fp_add.restype = c_uint64
```

This wasn't about deep mathematical reasoning, but about understanding syntactic and structural transformations. In this role, AI acted as a highly efficient, context-aware translator, saving significant manual effort in bridging the Python and C worlds.

## The Endless Debugging Maze: AI's Blind Spot for Root Causes

As the library expanded, so did the complexity of the RTL and the UVM testbenches. With each new operation or precision, new failures would inevitably surface. And here, the "AI Debugging Loop of Despair" from Phase 2 of my previous post returned with a vengeance.

When presented with a failing UVM log, Gemini would still offer beautifully formatted, yet often irrelevant, "fixes." It could identify syntax errors or suggest minor structural changes, but it consistently failed to grasp the subtle interactions between the RTL's pipeline stages, the UVM scoreboard's timing expectations, or the precise bit manipulations required for correct floating-point behavior.

Debugging a `UVM_ERROR` often involved hours of manual data flow analysis, tracing bits through computations, and comparing the RTL and the golden model bit-by-bit. Prompting the AI quickly created tools like `parse_simlog.py` that help extract relevant hex values from failing log entries, but the *interpretation* of why `0x1286 * 0x8e9c` resulted in `0x7e00` instead of `0x8005` (a NaN instead of a denormal number) remained a deeply human task. The AI could not "see" the point in the dataflow where things went awry or understand the implications of a single misplaced bit in a complex datapath. It also didn't know a crucial piece of wisdom: C bit-shift operations behave differently than Python's. In C, shifting by a value larger than the operand's bit width results in undefined behavior, which often leaves the bits in place to mess up the final result, unlike Python's behavior of shifting to zero.

## The Code Generation Machine: Repetitive Tasks, AI's Forte

While the AI struggled with high-level strategy, it excelled at low-level, repetitive tasks. Consider the lookup tables (LUTs) required for initial approximations in operations like inverse square root (`invsqrt`) and reciprocal (`recip`). These are essentially large `case` statements mapping an input address to a pre-calculated output value.

While the *calculation* of the ideal output values for these LUTs required a precise, human-written script (`generate_lut.py`), Gemini was excellent at drafting the Verilog module structure, the `always @(*)` block, and the `case` statement boilerplate.

```verilog
// Example of AI-generated LUT structure
module invsqrt_lut_16b (
    input  [4:0] addr,
    output reg [12:0] data
);
    always @(*) begin
        case (addr)
            // ... hundreds of entries generated by script ...
        endcase
    end
endmodule
```

Similarly, once the core logic for `fp16_add` was solid, asking Gemini to adapt it for `fp32_add` or even the parameterized version `fp_add` often yielded a good starting point. It could correctly adjust bit widths, exponent/mantissa sizes, and even some of the basic structural changes. It could not correctly insert a `grs_rounder` module into the datapath, messing up greatly and not being able to fix the mess. The generated code still needed thorough human review and often significant corrections for the subtle details, but it saved immense time in laying down the initial "metal."

Even for utility scripts like `path_comment.py`, which automates adding file path comments, Gemini could quickly provide a functional draft, understanding the file system traversal and string manipulation required, but finalizing it to a working state was purely human effort.

## The Ongoing Partnership

My journey with Gemini continues to be a partnership of complementary strengths. The AI is an unparalleled engine for generating volume, translating between languages, and automating repetitive structural tasks. It provides the "first 80%" with incredible speed.

However, the "final 20%"—the critical thinking, the deep mathematical insight, the systematic debugging, and the nuanced understanding of hardware behavior—remains firmly in the human domain. As the floating-point library grows, this division of labor becomes not just efficient, but essential. The vibe is still there, but now it's backed by rigorous, human-engineered logic.

The next step: tackling more complex operations and refining the verification environment further.

 #verilog #rtl #vibecoding #OpenSource #ASIC #AI
