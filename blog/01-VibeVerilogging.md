# Vibe Verilogging - My Wild Ride Building an Open-Source Floating-Point Library with Gemini

Ilya I.  
2025-0917

![Vibe Verilogging](01-VibeVerilogging.png)

It started with a series of interviews. I’m a senior RTL design engineer with extensive experience in computational math—I shipped the Leapfrog Leapster ASIC back in the day and engineered numerous high-speed instrumentation designs, like a 12Gbps clock recovery instrument for Tektronix and a 1.2GS/s real-time disk drive tester. And also an Ultrasound imaging design that restores 3D tissue structure from piezo sensor matrix.

But because those high-performance projects relied on fixed-point math to squeeze out every last drop of performance, my resume didn't specifically include shipping floating-point (FP) hardware.

Yet, in a couple recent interviews, I was rejected due to a perceived lack of FP arithmetic experience. To me, that said more about the interviewers, but it was still a clear sign from the universe.

Instead of just brushing off the signal, I decided to go all-in and build something tangible: a complete, open-source Verilog RTL floating-point library. The goal was ambitious: create 16-bit (half-precision), 32-bit (single-precision), and 64-bit (double-precision) cells for all the key operations:

* Addition (add)  
* Multiplication (mul)  
* Division (div)  
* Reciprocal (recip)  
* Fused Multiply-Add (mul\_add) & Multiply-Subtract (mul\_sub)  
* Square Root (sqrt) & Inverse Square Root (invsqrt)

And, of course, it all had to be verified with proper UVM testbenches.

## Phase 1: Vibe Coding with My AI Co-Pilot

This is where I decided to embrace the future. I opened up Google Gemini and started what I now call "Vibe Verilogging." I’d describe the module and its precision, and Gemini would crank out code. And I mean a *ton* of code.

The initial results were aesthetically beautiful. The Verilog was well-formatted, the UVM testbenches looked plausible, and the sheer volume of generated code felt like incredible progress. It all *looked* and *felt* right. It had the vibe of a working FP library. The only problem? None of it actually worked.

Not a single simulation passed. It didn't even compile.

## Phase 2: The AI Debugging Loop of Despair

This is where the AI dream started to crumble. I reported the failures back to Gemini. "The UVM testbench is failing at this stage," I’d say. "The compiler throws errors."

Gemini would apologize politely and "fix" the code. The new code would also be beautifully formatted, logical-looking, and completely non-functional. We went in circles. The LLM would try to figure out its own mistakes, fail, generate a slightly different flavor of broken code, and the cycle would repeat. It was stuck in an endless loop of self-correction that never converged on a solution.

The vibe was gone. It was clear that a human with domain expertise had to step in. The AI had given me a mountain of code, but it was up to me to make it work.

## Phase 3: Rolling Up My Sleeves – The Human-in-the-Loop

The core issue was that the AI couldn't reason about the entire system, and it couldn't ask the right questions. It could generate *almost* syntactically correct code, but it lacked the deep understanding of Verilog nuances, RTL principles, and UVM details to debug the subtle interactions between the RTL, the UVM environment, and the mathematical models.

I had to take a step back and build a solid foundation of truth. My strategy became:

1. **Golden Model First:** I threw out the LLM's broken UVM model. Instead, I wrote a simple, clean C model for the FP operations. Using Verilog's DPI-C interface, I could compile this C code and call it directly from my UVM testbench. This gave me a reliable, "golden" reference to compare the RTL against.  
2. **Verify the Verifier:** How do I know my C model is correct? I built a separate Python-based verification suite just for the C code. Using libraries like NumPy, I could test the C model against industry-standard FP implementations across a massive range of values and corner cases.  
3. **Fixing the UVM:** With a trusted C model, the UVM issues became much clearer. The LLM's main struggle was with handling the pipeline for each cell correctly -- managing stimulus, collecting responses, and aligning them in time. I re-architected the testbench scoreboard to properly handle these pipeline delays, using my DPI-C model to provide the correct expected data at the right time.  
4. **Special FP Values:** I had to solve the problem that in FP there are many ambigous bits in special values that easily break tests. I had to manually add logic for **canonicalizing** model and DUT outputs for Not-a-Number (NaN) and Infinity (Inf) values. In floating-point, there are many ambiguous bits in these special values. Canonicalizing them ensures the hardware behaves predictably but also prevents tests from failing when one valid NaN representation is unimportantly different from another.  
5. **Finally, Debugging the RTL:** At last, I could focus on the RTL itself. The most significant issues were handling special values and managing internal precision and writing correct bit manipulations.

## Victory and Vindication

After two weeks of painstaking, manual debugging for a couple of hours a night, the moment of truth arrived. I kicked off the regressions, and one by one, the tests started turning green. **UVM\_TEST\_PASSED\!** It was a fantastic feeling. Of course, this is just the fp16\_add module for now, but it serves as a blueprint for all the rest of the cells.

The result of this journey is a robust, fully verified, open-source FP library. Now comes the time to share it with the community.

**You can find the entire library here on GitHub: [https://github.com/asic-now/hdl](https://github.com/asic-now/hdl)**

## My Takeaway: AI is a Tool, Not a Replacement

My "Vibe Verilogging" experiment taught me a valuable lesson about the current state of AI in RTL design. LLMs are powerful tools for generating boilerplate code and getting a first draft on paper. They can accelerate the initial, high-volume coding phase significantly.

However, they are not yet capable of the deep, critical thinking and systematic debugging required for complex hardware design. The nuanced, detail-oriented work of verification, corner-case analysis, and system-level debugging still falls squarely on the shoulders of the engineer.

Did I expect something different? Of course not. I've used LLMs for a full spectrum of technical problems -- including Verilog, Python, TypeScript, C, documentation, and diagrams -- and I expected the LLM to struggle, as it does in any moderately complex problem space. Where it shines is its almost perfect recall and its ability to grasp the questions well.

The future of hardware design will undoubtedly involve AI, but it will be a partnership. The AI can provide the "vibe" and the first 80%, but it's the experienced engineer who has to provide the rigor, the insight, and the final 20% that makes it actually work. And for now, that’s a pretty good place to be.
