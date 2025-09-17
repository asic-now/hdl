// fp16_sqrt.v
//
// Verilog RTL for a 16-bit (half-precision) floating-point square root.
//
// Operation: result = sqrt(a)
//
// Format (IEEE 754 half-precision):
// [   15]: Sign bit (1 for negative, 0 for positive)
// [14:10]: 5-bit exponent (bias of 15)
// [ 9: 0]: 10-bit mantissa (fraction/significand)
//
// Features:
// - Pipelined architecture using a non-restoring square root algorithm.
// - Fixed latency of 13 cycles.
// - Handles special cases: NaN, Infinity, Zero, and Negative Input.

module fp16_sqrt (
    input clk,
    input rst_n,
    input  [15:0] a,
    output [15:0] result
);

    // Latency for 11 bits of mantissa root calculation (10 frac + 1 integer)
    localparam SQRT_LATENCY = 11;
    localparam TOTAL_LATENCY = SQRT_LATENCY + 1;

    //----------------------------------------------------------------
    // Stage 1: Unpack and Handle Special Cases
    //----------------------------------------------------------------
    
    wire       sign_a = a[15];
    wire [4:0] exp_a  = a[14:10];
    wire [9:0] mant_a = a[9:0];

    // Detect special values
    wire is_nan_a = (exp_a == 5'h1F) && (mant_a != 0);
    wire is_inf_a = (exp_a == 5'h1F) && (mant_a == 0);
    wire is_zero_a = (exp_a == 0) && (mant_a == 0);
    wire is_neg_normal = (sign_a == 1'b1) && !is_zero_a;

    // Add implicit leading bit
    wire [10:0] full_mant_a = {(exp_a != 0), mant_a};

    // Stage 1 Pipeline Registers
    reg         s1_special_case;
    reg  [15:0] s1_special_result;
    reg  signed [5:0] s1_exp_res;
    reg  [10:0] s1_radicand; // The number to be square-rooted

    always @(posedge clk) begin
        if (!rst_n) begin
            s1_special_case <= 1'b0;
            s1_special_result <= 16'b0;
            s1_exp_res <= 6'b0;
            s1_radicand <= 11'b0;
        end else begin
            // Default path for normal operation
            s1_special_case <= 1'b0;

            // For sqrt, the exponent must be even. If it's odd, we adjust it
            // and shift the mantissa to compensate. (sqrt(m*2^e) = sqrt(m/2)*2^((e+1)/2))
            if(exp_a[0]) begin // Odd exponent
                s1_exp_res <= {{1'b0, exp_a} + 1} >> 1;
                s1_radicand <= full_mant_a << 1;
            end else begin // Even exponent
                s1_exp_res <= {1'b0, exp_a} >> 1;
                s1_radicand <= full_mant_a;
            end

            // Handle special cases
            if (is_nan_a || is_neg_normal) begin
                s1_special_case <= 1'b1;
                s1_special_result <= 16'h7E01; // qNaN
            end else if (is_inf_a) begin
                s1_special_case <= 1'b1;
                s1_special_result <= 16'h7C00; // +Infinity
            end else if (is_zero_a) begin
                s1_special_case <= 1'b1;
                s1_special_result <= 16'h0000; // +Zero
            end
        end
    end

    //----------------------------------------------------------------
    // Pipelined Square Root Core
    //----------------------------------------------------------------
    
    reg  [11:0] rem_pipe [0:SQRT_LATENCY];
    reg  [10:0] root_pipe [0:SQRT_LATENCY];

    always @(posedge clk) begin
        if (!rst_n) begin
            rem_pipe[0] <= 12'b0;
            root_pipe[0] <= 11'b0;
        end else begin
            rem_pipe[0] <= {2'b0, s1_radicand};
            root_pipe[0] <= 11'b0;
        end
    end

    genvar i;
    generate
        for (i = 0; i < SQRT_LATENCY; i = i + 1) begin : sqrt_stages
            // Non-restoring algorithm step
            wire [10:0] trial_root = {root_pipe[i], 1'b1};
            wire [11:0] trial_rem = (rem_pipe[i][11]) 
                ? {rem_pipe[i][9:0], 2'b00} + {1'b0, trial_root}
                : {rem_pipe[i][9:0], 2'b00} - {1'b0, trial_root};

            always @(posedge clk) begin
                if(!rst_n) begin
                    rem_pipe[i+1] <= 12'b0;
                    root_pipe[i+1] <= 11'b0;
                end else begin
                    rem_pipe[i+1] <= trial_rem;
                    root_pipe[i+1] <= trial_rem[11] ? {root_pipe[i], 1'b0} : {root_pipe[i], 1'b1};
                end
            end
        end
    endgenerate

    // Pipeline to carry special flags and results alongside the core
    reg [TOTAL_LATENCY:0] special_case_pipe;
    reg [15:0] special_result_pipe [TOTAL_LATENCY:0];
    reg signed [5:0] exp_res_pipe [TOTAL_LATENCY:0];

    always @(posedge clk) begin
        special_case_pipe[0] <= s1_special_case;
        special_result_pipe[0] <= s1_special_result;
        exp_res_pipe[0] <= s1_exp_res;
    end
    
    generate
        for(i=0; i<TOTAL_LATENCY; i=i+1) begin : prop_pipe
            always @(posedge clk) begin
                special_case_pipe[i+1] <= special_case_pipe[i];
                special_result_pipe[i+1] <= special_result_pipe[i];
                exp_res_pipe[i+1] <= exp_res_pipe[i];
            end
        end
    endgenerate

    //----------------------------------------------------------------
    // Final Stage: Normalize and Pack
    //----------------------------------------------------------------
    
    wire [10:0] final_root = root_pipe[SQRT_LATENCY];
    
    wire signed [5:0] final_exp = (exp_res_pipe[TOTAL_LATENCY] - 15) + 15;
    reg         [9:0] out_mant;
    reg         [4:0] out_exp;
    
    always @(*) begin
        out_mant = final_root[9:0]; // The root is already normalized as 1.f
        if (final_exp >= 31) begin // Overflow
            out_exp = 5'h1F;
            out_mant = 10'b0;
        end else if (final_exp <= 0) begin // Underflow
            out_mant = ({1'b1, final_root[9:0]}) >> (1 - final_exp);
            out_exp = 5'b0;
        end else begin
            out_exp = final_exp[4:0];
        end
    end
    
    reg [15:0] result_reg;
    always @(posedge clk) begin
        if (!rst_n) begin
            result_reg <= 16'b0;
        end else begin
            if (special_case_pipe[TOTAL_LATENCY]) begin
                result_reg <= special_result_pipe[TOTAL_LATENCY];
            end else begin
                result_reg <= {1'b0, out_exp, out_mant};
            end
        end
    end
    
    assign result = result_reg;

endmodule
