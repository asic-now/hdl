// fp16_div.v
//
// Verilog RTL for a 16-bit (half-precision) floating-point divider.
//
// Operation: result = a / b
//
// Format (IEEE 754 half-precision):
// [   15]: Sign bit (1 for negative, 0 for positive)
// [14:10]: 5-bit exponent (bias of 15)
// [ 9: 0]: 10-bit mantissa (fraction/significand)
//
// Features:
// - Fixed-latency 13-stage pipelined architecture.
// - Uses a pipelined restoring division algorithm for the mantissa.
// - Handles normalized and denormalized numbers.
// - Handles special cases: NaN, Infinity, Zero, and Division by Zero.
// - Truncates the result.

`include "fp16_inc.vh"

module fp16_div (
    input clk,
    input rst_n,
    input  [15:0] a,
    input  [15:0] b,
    output [15:0] result
);

    // Latency of the divider core = 11 cycles for mantissa bits
    localparam DIV_LATENCY = 11;
    localparam TOTAL_LATENCY = DIV_LATENCY + 1;

    //----------------------------------------------------------------
    // Stage 1: Unpack and Handle Special Cases
    //----------------------------------------------------------------
    
    wire       sign_a = a[15];
    wire [4:0] exp_a  = a[14:10];
    wire [9:0] mant_a = a[9:0];

    wire       sign_b = b[15];
    wire [4:0] exp_b  = b[14:10];
    wire [9:0] mant_b = b[9:0];

    // Detect special values
    wire is_nan_a = (exp_a == 5'h1F) && (mant_a != 0);
    wire is_inf_a = (exp_a == 5'h1F) && (mant_a == 0);
    wire is_zero_a = (exp_a == 0) && (mant_a == 0);

    wire is_nan_b = (exp_b == 5'h1F) && (mant_b != 0);
    wire is_inf_b = (exp_b == 5'h1F) && (mant_b == 0);
    wire is_zero_b = (exp_b == 0) && (mant_b == 0);

    // Add implicit leading bit
    wire [10:0] full_mant_a = {(exp_a != 0), mant_a};
    wire [10:0] full_mant_b = {(exp_b != 0), mant_b};

    wire [ 5:0] eff_exp_a = (exp_a == 0) ? 1 : exp_a;
    wire [ 5:0] eff_exp_b = (exp_b == 0) ? 1 : exp_b;

    // Stage 1 Pipeline Registers
    reg        s1_special_case;
    reg [15:0] s1_special_result;
    reg signed [5:0] s1_exp_res;
    reg        s1_sign_res;
    reg [20:0] s1_dividend; // For (mant_a << 10)
    reg [10:0] s1_divisor;

    always @(posedge clk) begin
        if (!rst_n) begin
            s1_special_case <= 1'b0;
            s1_special_result <= 16'b0;
            s1_exp_res <= 6'b0;
            s1_sign_res <= 1'b0;
            s1_dividend <= 21'b0;
            s1_divisor <= 11'b0;
        end else begin
            // Default path for normal operation
            s1_special_case <= 1'b0;
            s1_dividend <= {full_mant_a, 10'b0};
            s1_divisor <= full_mant_b;
            s1_sign_res <= sign_a ^ sign_b;

            s1_exp_res <= eff_exp_a - eff_exp_b + 15;

            // Handle special cases
            if (is_nan_a || is_nan_b || (is_inf_a && is_inf_b) || (is_zero_a && is_zero_b)) begin
                s1_special_case <= 1'b1;
                s1_special_result <= `FP16_QNAN; // qNaN
            end else if (is_inf_a || is_zero_b) begin
                s1_special_case <= 1'b1;
                s1_special_result <= {sign_a ^ sign_b, 5'h1F, 10'b0}; // Infinity
            end else if (is_zero_a || is_inf_b) begin
                s1_special_case <= 1'b1;
                s1_special_result <= {sign_a ^ sign_b, 15'b0}; // Zero
            end
        end
    end

    //----------------------------------------------------------------
    // Pipelined Divider Core (11 Stages)
    //----------------------------------------------------------------
    
    // Arrays of registers to pipeline the division state
    reg  [11:0] rem_pipe [0:DIV_LATENCY];
    reg  [20:0] dividend_pipe [0:DIV_LATENCY];
    reg  [10:0] divisor_pipe [0:DIV_LATENCY];
    reg  [10:0] quotient_pipe [0:DIV_LATENCY];

    // Initialize first stage of the divider pipeline
    always @(posedge clk) begin
        if (!rst_n) begin
            rem_pipe[0] <= 12'b0;
            dividend_pipe[0] <= 21'b0;
            divisor_pipe[0] <= 11'b0;
            quotient_pipe[0] <= 11'b0;
        end else begin
            rem_pipe[0] <= 12'b0;
            dividend_pipe[0] <= s1_dividend;
            divisor_pipe[0] <= s1_divisor;
            quotient_pipe[0] <= 11'b0;
        end
    end

    // Generate the divider stages
    genvar i;
    generate
        for (i = 0; i < DIV_LATENCY; i = i + 1) begin : div_stages
            // Combinational logic for one stage of restoring division
            wire [11:0] shifted_rem = {rem_pipe[i][10:0], dividend_pipe[i][20]};
            wire [11:0] sub_res = shifted_rem - {1'b0, divisor_pipe[i]};
            wire q_bit = ~sub_res[11];

            // Register the results for the next stage
            always @(posedge clk) begin
                if(!rst_n) begin
                    rem_pipe[i+1] <= 12'b0;
                    dividend_pipe[i+1] <= 21'b0;
                    divisor_pipe[i+1] <= 11'b0;
                    quotient_pipe[i+1] <= 11'b0;
                end else begin
                    rem_pipe[i+1] <= q_bit ? sub_res[10:0] : shifted_rem[10:0];
                    dividend_pipe[i+1] <= dividend_pipe[i] << 1;
                    divisor_pipe[i+1] <= divisor_pipe[i];
                    quotient_pipe[i+1] <= {quotient_pipe[i][9:0], q_bit};
                end
            end
        end
    endgenerate

    // Pipeline to carry special flags and results alongside the divider
    reg [TOTAL_LATENCY:0] special_case_pipe;
    reg [15:0] special_result_pipe [TOTAL_LATENCY:0];
    reg signed [5:0] exp_res_pipe [TOTAL_LATENCY:0];
    reg sign_res_pipe [TOTAL_LATENCY:0];

    always @(posedge clk) begin
        if(!rst_n) begin
            special_case_pipe[0] <= 1'b0;
            special_result_pipe[0] <= 16'b0;
            exp_res_pipe[0] <= 6'b0;
            sign_res_pipe[0] <= 1'b0;
        end else begin
            special_case_pipe[0] <= s1_special_case;
            special_result_pipe[0] <= s1_special_result;
            exp_res_pipe[0] <= s1_exp_res;
            sign_res_pipe[0] <= s1_sign_res;
        end
    end
    
    generate
        for(i=0; i<TOTAL_LATENCY; i=i+1) begin : prop_pipe
            always @(posedge clk) begin
                if(!rst_n) begin
                    special_case_pipe[i+1] <= 1'b0;
                    special_result_pipe[i+1] <= 16'b0;
                    exp_res_pipe[i+1] <= 6'b0;
                    sign_res_pipe[i+1] <= 1'b0;
                end else begin
                    special_case_pipe[i+1] <= special_case_pipe[i];
                    special_result_pipe[i+1] <= special_result_pipe[i];
                    exp_res_pipe[i+1] <= exp_res_pipe[i];
                    sign_res_pipe[i+1] <= sign_res_pipe[i];
                end
            end
        end
    endgenerate

    //----------------------------------------------------------------
    // Final Stage: Normalize and Pack
    //----------------------------------------------------------------
    
    // Result of the mantissa division
    wire [10:0] final_quotient = quotient_pipe[DIV_LATENCY];
    
    // Normalize the mantissa and adjust exponent
    reg  signed [5:0] final_exp;
    reg         [9:0] final_mant;
    
    always @(*) begin
        // The quotient is in the format i.f... where i is quotient[10].
        // If i=0, the result is < 1.0 and must be normalized left.
        if(!final_quotient[10]) begin
            final_exp = exp_res_pipe[TOTAL_LATENCY] - 1;
            final_mant = final_quotient[9:0]; 
        end else begin
            final_exp = exp_res_pipe[TOTAL_LATENCY];
            final_mant = final_quotient[9:0];
        end
    end
    
    // Handle final exponent overflow/underflow
    reg  [ 4:0] out_exp;
    reg  [ 9:0] out_mant;
    
    always @(*) begin
        out_exp = final_exp[4:0];
        out_mant = final_mant;
        
        if (final_exp >= 31) begin // Overflow -> Inf
            out_exp = 5'h1F;
            out_mant = 10'b0;
        end else if (final_exp <= 0) begin // Underflow -> Denormalized or Zero
            out_mant = ({1'b1, final_mant}) >> (1 - final_exp);
            out_exp = 5'b0;
        end
    end
    
    // Final registered output
    reg  [15:0] result_reg;
    always @(posedge clk) begin
        if (!rst_n) begin
            result_reg <= 16'b0;
        end else begin
            if (special_case_pipe[TOTAL_LATENCY]) begin
                result_reg <= special_result_pipe[TOTAL_LATENCY];
            end else if (out_exp == 0 && out_mant == 0) begin
                result_reg <= {sign_res_pipe[TOTAL_LATENCY], 15'b0};
            end else begin
                result_reg <= {sign_res_pipe[TOTAL_LATENCY], out_exp, out_mant};
            end
        end
    end
    
    assign result = result_reg;

endmodule
