# The Systolic Symphony: Composing a Matrix Multiplication Engine

Ilya I.  
2026-01-22

![The Systolic Symphony](03-TheSystolicSymphony.png)

The journey so far - from "[Vibe Verilogging](01-VibeVerilogging.md)" to "[Beyond the Vibe](02-BeyondTheVibe.md)," has been about building the fundamental notes of computation: a robust, parameterized floating-point library. We wrestled in `#VibeVerilogging` with AI, tamed UVM, and forged bit-accurate models. But individual notes, no matter how perfect, don't make a symphony.

The next grand challenge was to compose these notes into a powerful chorus: a hardware accelerator for matrix multiplication, the heart of modern AI and scientific computing.

The natural choice? A **Systolic Array** - an elegant grid of interconnected Processing Elements (PEs) that rhythmically pump data to perform massive parallel computations. (For context, Google's TPU v1 used a massive 256x256 systolic array).

Once again, I turned to my AI partner, Gemini, to get the first draft on the page. And once again, the difference between "generating code" and "designing architecture" became the central theme of our collaboration.

## The AI's Overture: A Textbook Implementation

I asked Gemini for a standard weight-stationary 2x2 systolic array using a simple int4 PE.

The result was aesthetically pleasing Verilog: a fixed 2D grid of PEs, correctly connected, with data streaming in from the left and weights from top. It was an (almost) functional textbook implementation of a **Weight-Stationary (WS)** array.

Gemini struggled to create a robust control logic block. It initially proposed 2 state machines to separate control of A and B inputs flow. Close to working, but it had one-off pulse timing issues, and attempts to fix it led to a convoluted mess of conditional flags and additional pipelines. It was failing to comprehend its own design of the pipelined PE in the array structure, and struggled to align the fixed pipelines.

It looks like Gemini gets out of its depth with complex "3D" pipelines like this. This wasn't surprising; it struggled similarly with the 1D pipelines inside the ADD and MUL blocks.

I went through 5 different designs with Gemini, each one not working correctly. Then I pulled Gemini off and fixed the pipelines alignment myself by separating and cleaning up the linked FSM logic blocks.

We got a functional design with a simple test bench.

## Compute Utilization

But in hardware design, "functional" is often a synonym for "slow."

A naive systolic array suffers from a massive utilization crisis. The data flows in a wave; when the wave starts, most PEs are idle. When the wave ends, they go idle again. If you stop to load new weights between computations, your expensive silicon sits doing nothing for 75% of the time.

## The Human Architect: Optimization is a Choice

This is where the human architect steps in. The AI provided the baseline, but I had to guide it through the design space of **Weight-Buffering Schemes** to chase that elusive 100% utilization.

### Option 1: Single Buffered (The AI Default)

The simplest approach. You stop computation, load the new weights for Matrix B, and then restart.

* **The Vibe:** Easy to implement.
* **The Reality:** For a square array, your utilization is roughly **25%**. You are spending more time loading and draining the array than actually computing. And the bigger the array... the longer it sits idle.

### Option 2: Double Buffered with Global Update

We added a second register to every PE. We load the next set of weights in the background while the current math happens, and then send an "update" signal to load the weights into WS registers for next compute.

* **The Vibe:** "Look, I'm hiding memory latency!"
* **The Reality:** You still have a synchronization penalty. You must wait for the "slowest" PE (the bottom-right corner) to finish its current batch before flipping the switch for everyone. Utilization bumps to **~33%**. Better, but still inefficient.

### Option 3: Double Buffered with Wavefront Update (The Winner)

This is where the magic happens. Instead of a global "switch weights now" signal, we pipeline the update signal itself.

* **The Vibe:** Maximum complexity, maximum glory.
* **The Reality:** The `b_update` signal propagates through the array as a wavefront, moving diagonally with the data. PE(0,0) switches to the new batch, and one cycle later PE(0,1) and PE(1,0) switch. The array never stops. One computation wave chases the next immediately. **Utilization: 100%**.

Implementing Option 3 requires a level of spatio-temporal reasoning that LLMs may struggle with. It's not just about connecting wires; it's about visualizing data flowing through time and space simultaneously. Surprisingly, Gemini had no problem comprehending the task and adding correct pipelining logic for the "update" signal wave once the concept was established.

## The Quest for Full Parameterization

A rigid systolic array is a toy. To make this a real tool, we needed deep parameterization. And I don't just mean `DATA_WIDTH`.

We started with a fixed 2x2 array using int4 PEs for scaffolding. Gemini initially generated a hard-wired structure. I nudged it towards using `generate` loops to enable parameterization. It handled that refactoring easily.

Later it was able to fully parameterize ROWS and COLS for the array size, and then we added WIDTH, ACC_WIDTH parameters with no problem.

To make the design ready for FP library, we needed a critical architectural split of the Processing Element's pipeline into two distinct parameters:

1. **`MUL_LATENCY`**: Cycles consumed by the multiplication.
2. **`ADD_LATENCY`**: Cycles consumed by the accumulation.

**Why split the pipeline?**

In high-performance silicon, especially for floating-point, a 1-cycle ALU is a myth. A real floating-point multiplier might take 3 cycles, and an adder might take 2. By parameterizing these independently, we accomplish two things:

1. **Modeling Reality**: We can simulate the exact pipeline depth of our target technology.
2. **Future Proofing for Fused MACs**: This prepares the ground for swapping in a high-speed **Fused Multiply-Add (FMA)** unit. An FMA unit merges the multiply and add steps into a single, deep pipeline. By supporting arbitrary latencies now, we ensure our control logic can handle the deep pipelines of advanced FMA units without stalling or corrupting data.

## The 3D Pipeline Puzzle

Designing this control logic reveals the 3D nature of the problem. A systolic array looks like a 2D grid on paper, but it's a 3D structure where the third dimension is PE internal pipeline.

Data doesn't just enter; it must arrive at specific coordinates at specific times to meet other data arriving from orthogonal directions.

```text
Time ->   T0   T1   T2   T3
Row 0:  [A00] [A01] [A02] ...
Row 1:   -    [A10] [A11] [A12] ...
Row 2:   -     -    [A20] [A21] [A22] ...
```

If `MUL_LATENCY` increases, the vertical skew of the partial sums must change. If the `ADD_LATENCY` changes, the timing of the readout shifts. The "systolic" rhythm - the heartbeat of the machine - depends entirely on these latencies.

When adding `MUL_LATENCY` and `ADD_LATENCY` parameters, Gemini struggled again, as it drastically changed the alignment requirements in the 3D pipeline. Even though the control block design I provided had the correct structure, applying the parameters correctly to the skew logic was beyond the AI.

I had to manually parameterize the control logic myself.

We finally had a fully parameterized, functional systolic array.

## UVM Testbench

Gemini shined in writing all the UVM blocks, converting a simple testbench into a proper parameterized verification environment with constraint-driven randomized test sequences.

But it had a great template to work from - UVM testbenches for parameterized FP cells (covered in "[Vibe Verilogging](01-VibeVerilogging.md)"). It mostly copied validated UVM module designs, I did few fixes directly or by prompts, and we got full testbench.

## Conclusion: The Conductor and the Orchestra

The Systolic Array is now live in the repository. It supports:

* Arbitrary array dimensions (ROWS x COLS).
* Configurable data widths.
* **Independent ALU pipeline latencies** (MUL vs. ADD).
* **100% Utilization** via Wavefront Weight Updates.

This module is the perfect example of the new era of hardware design. The AI is the orchestra, capable of playing the notes and generating the volume of code required. But the engineer is the conductor, choosing the tempo, selecting the architecture (Option 3 over Option 1), and ensuring the symphony resolves correctly in time and space.

**You can find the systolic array implementation here on GitHub:**

<https://github.com/asic-now/hdl>

 #verilog #rtl #systolicarray #matrixmultiplication #ASIC #AI #FPGA
