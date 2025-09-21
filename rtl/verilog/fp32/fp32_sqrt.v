// rtl/verilog/fp32/fp32_sqrt.v
//
// Verilog RTL for a 32-bit (single-precision) floating-point square root.
//
// Operation: result = sqrt(a)
//
// Format (IEEE 754 single-precision):
// [31]   : Sign bit
// [30:23]: 8-bit exponent (bias of 127)
// [22:0] : 23-bit mantissa
//
// Features:
// - Pipelined architecture using a non-restoring square root algorithm.
// - Fixed latency of 26 cycles.
// - Handles special cases: NaN, Infinity, Zero, and Negative Input.

module fp32_sqrt (
    input clk,
    input rst_n,
    input  [31:0] a,
    output [31:0] result
);

    // Latency for 24 bits of mantissa root calculation (23 frac + 1 integer)
    localparam SQRT_LATENCY = 24;
    localparam TOTAL_LATENCY = SQRT_LATENCY + 1;

    //----------------------------------------------------------------
    // Stage 1: Unpack and Handle Special Cases
    //----------------------------------------------------------------
    
    wire        sign_a = a[31];
    wire [ 7:0] exp_a  = a[30:23];
    wire [22:0] mant_a = a[22:0];

    // Detect special values
    wire is_nan_a = (exp_a == 8'hFF) && (mant_a != 0);
    wire is_inf_a = (exp_a == 8'hFF) && (mant_a == 0);
    wire is_zero_a = (exp_a == 0) && (mant_a == 0);
    wire is_neg_normal = (sign_a == 1'b1) && !is_zero_a;

    // Add implicit leading bit
    wire [23:0] full_mant_a = {(exp_a != 0), mant_a};

    // Stage 1 Pipeline Registers
    reg         s1_special_case;
    reg  [31:0] s1_special_result;
    reg  signed [8:0] s1_exp_res;
    reg  [24:0] s1_radicand;

    always @(posedge clk) begin
        if (!rst_n) begin
            s1_special_case <= 1'b0;
            s1_special_result <= 32'b0;
            s1_exp_res <= 9'b0;
            s1_radicand <= 25'b0;
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
                s1_special_result <= 32'h7FC00001; // qNaN
            end else if (is_inf_a) begin
                s1_special_case <= 1'b1;
                s1_special_result <= 32'h7F800000; // +Infinity
            end else if (is_zero_a) begin
                s1_special_case <= 1'b1;
                s1_special_result <= 32'h00000000; // +Zero
            end
        end
    end

    //----------------------------------------------------------------
    // Pipelined Square Root Core
    //----------------------------------------------------------------
    
    reg  [25:0] rem_pipe [0:SQRT_LATENCY];
    reg  [23:0] root_pipe [0:SQRT_LATENCY];

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
            wire [23:0] trial_root = {root_pipe[i], 1'b1};
            wire [25:0] trial_rem = (rem_pipe[i][25])
                ? {rem_pipe[i][23:0], 2'b00} + {2'b0, trial_root}
                : {rem_pipe[i][23:0], 2'b00} - {2'b0, trial_root};

            always @(posedge clk) begin
                if(!rst_n) begin
                    rem_pipe[i+1] <= 12'b0;
                    root_pipe[i+1] <= 11'b0;
                end else begin
                    rem_pipe[i+1] <= trial_rem;
                    root_pipe[i+1] <= trial_rem[25] ? {root_pipe[i], 1'b0} : {root_pipe[i], 1'b1};
                end
            end
        end
    endgenerate

    // Pipeline to carry special flags and results alongside the core
    reg [TOTAL_LATENCY:0] special_case_pipe;
    reg [31:0] special_result_pipe [TOTAL_LATENCY:0];
    reg signed [8:0] exp_res_pipe [TOTAL_LATENCY:0];

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
    
    wire [23:0] final_root = root_pipe[SQRT_LATENCY];
    
    wire signed [ 8:0] final_exp = (exp_res_pipe[TOTAL_LATENCY] - 127) + 127;
    reg         [22:0] out_mant;
    reg         [ 7:0] out_exp;
    
    always @(*) begin
        out_mant = final_root[22:0];
        if (final_exp >= 255) begin // Overflow
            out_mant = 23'b0;
            out_exp = 8'hFF;
        end else if (final_exp <= 0) begin // Underflow
            out_mant = ({1'b1, final_root[22:0]}) >> (1 - final_exp);
            out_exp = 8'b0;
        end else begin
            out_exp = final_exp[7:0];
        end
    end
    
    reg [31:0] result_reg;
    always @(posedge clk) begin
        if (!rst_n) begin
            result_reg <= 32'b0;
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
