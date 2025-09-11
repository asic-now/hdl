// fp64_div.v
//
// Verilog RTL for a 64-bit (double-precision) floating-point divider.
//
// Operation: result = a / b
//
// Format (IEEE 754 double-precision):
// [63]   : Sign bit
// [62:52]: 11-bit exponent (bias of 1023)
// [51:0] : 52-bit mantissa
//
// Features:
// - Fixed-latency 55-stage pipelined architecture.
// - Uses a pipelined restoring division algorithm for the mantissa.
// - Handles normalized and denormalized numbers.
// - Handles special cases: NaN, Infinity, Zero, and Division by Zero.
// - Truncates the result.

module fp64_div (
    input clk,
    input rst_n,
    input  [63:0] a,
    input  [63:0] b,
    output [63:0] result
);

    // Latency of the divider core = 53 cycles (52 mantissa bits + 1 integer bit)
    localparam DIV_LATENCY = 53;
    localparam TOTAL_LATENCY = DIV_LATENCY + 1;

    //----------------------------------------------------------------
    // Stage 1: Unpack and Handle Special Cases
    //----------------------------------------------------------------
    
    wire sign_a = a[63];
    wire [10:0] exp_a = a[62:52];
    wire [51:0] mant_a = a[51:0];

    wire sign_b = b[63];
    wire [10:0] exp_b = b[62:52];
    wire [51:0] mant_b = b[51:0];

    // Detect special values
    wire is_nan_a = (exp_a == 11'h7FF) && (mant_a != 0);
    wire is_inf_a = (exp_a == 11'h7FF) && (mant_a == 0);
    wire is_zero_a = (exp_a == 0) && (mant_a == 0);

    wire is_nan_b = (exp_b == 11'h7FF) && (mant_b != 0);
    wire is_inf_b = (exp_b == 11'h7FF) && (mant_b == 0);
    wire is_zero_b = (exp_b == 0) && (mant_b == 0);

    // Add implicit leading bit
    wire [52:0] full_mant_a = {(exp_a != 0), mant_a};
    wire [52:0] full_mant_b = {(exp_b != 0), mant_b};

    wire [11:0] eff_exp_a = (exp_a == 0) ? 1 : exp_a;
    wire [11:0] eff_exp_b = (exp_b == 0) ? 1 : exp_b;

    // Stage 1 Pipeline Registers
    reg        s1_special_case;
    reg [63:0] s1_special_result;
    reg signed [11:0] s1_exp_res;
    reg        s1_sign_res;
    reg [104:0] s1_dividend; // For (mant_a << 52)
    reg [52:0] s1_divisor;
    always @(posedge clk) begin
        if (!rst_n) begin
            s1_special_case <= 1'b0;
            s1_special_result <= 64'b0;
            s1_exp_res <= 12'b0;
            s1_sign_res <= 1'b0;
            s1_dividend <= 105'b0;
            s1_divisor <= 53'b0;
        end else begin
            // Default path for normal operation
            s1_special_case <= 1'b0;
            s1_dividend <= {full_mant_a, 52'b0};
            s1_divisor <= full_mant_b;
            s1_sign_res <= sign_a ^ sign_b;

            s1_exp_res <= eff_exp_a - eff_exp_b + 1023;

            // Handle special cases
            if (is_nan_a || is_nan_b || (is_inf_a && is_inf_b) || (is_zero_a && is_zero_b)) begin
                s1_special_case <= 1'b1;
                s1_special_result <= 64'h7FF8000000000001; // qNaN
            end else if (is_inf_a || is_zero_b) begin
                s1_special_case <= 1'b1;
                s1_special_result <= {sign_a ^ sign_b, 11'h7FF, 52'b0}; // Infinity
            end else if (is_zero_a || is_inf_b) begin
                s1_special_case <= 1'b1;
                s1_special_result <= {sign_a ^ sign_b, 63'b0}; // Zero
            end
        end
    end

    //----------------------------------------------------------------
    // Pipelined Divider Core (53 Stages)
    //----------------------------------------------------------------
    
    reg [53:0] rem_pipe [0:DIV_LATENCY];
    reg [104:0] dividend_pipe [0:DIV_LATENCY];
    reg [52:0] divisor_pipe [0:DIV_LATENCY];
    reg [52:0] quotient_pipe [0:DIV_LATENCY];

    always @(posedge clk) begin
        if (!rst_n) begin
            rem_pipe[0] <= 54'b0;
            dividend_pipe[0] <= 105'b0;
            divisor_pipe[0] <= 53'b0;
            quotient_pipe[0] <= 53'b0;
        end else begin
            rem_pipe[0] <= 54'b0;
            dividend_pipe[0] <= s1_dividend;
            divisor_pipe[0] <= s1_divisor;
            quotient_pipe[0] <= 53'b0;
        end
    end

    genvar i;
    generate
        for (i = 0; i < DIV_LATENCY; i = i + 1) begin : div_stages
            wire [53:0] shifted_rem = {rem_pipe[i][52:0], dividend_pipe[i][104]};
            wire [53:0] sub_res = shifted_rem - {1'b0, divisor_pipe[i]};
            wire q_bit = ~sub_res[53];

            always @(posedge clk) begin
                if(!rst_n) begin
                    rem_pipe[i+1] <= 54'b0;
                    dividend_pipe[i+1] <= 105'b0;
                    divisor_pipe[i+1] <= 53'b0;
                    quotient_pipe[i+1] <= 53'b0;
                end else begin
                    rem_pipe[i+1] <= q_bit ? sub_res : shifted_rem;
                    dividend_pipe[i+1] <= dividend_pipe[i] << 1;
                    divisor_pipe[i+1] <= divisor_pipe[i];
                    quotient_pipe[i+1] <= {quotient_pipe[i][51:0], q_bit};
                end
            end
        end
    endgenerate

    // Pipeline to carry special flags and results alongside the divider
    reg [TOTAL_LATENCY:0] special_case_pipe;
    reg [63:0] special_result_pipe [TOTAL_LATENCY:0];
    reg signed [11:0] exp_res_pipe [TOTAL_LATENCY:0];
    reg sign_res_pipe [TOTAL_LATENCY:0];

    always @(posedge clk) begin
        if(!rst_n) begin
            special_case_pipe[0] <= 1'b0;
            special_result_pipe[0] <= 64'b0;
            exp_res_pipe[0] <= 12'b0;
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
                    special_result_pipe[i+1] <= 64'b0;
                    exp_res_pipe[i+1] <= 12'b0;
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
    
    wire [52:0] final_quotient = quotient_pipe[DIV_LATENCY];
    
    reg signed [11:0] final_exp;
    reg        [51:0] final_mant;
    
    always @(*) begin
        if(!final_quotient[52]) begin // result < 1.0, normalize left
            final_exp = exp_res_pipe[TOTAL_LATENCY] - 1;
            final_mant = final_quotient[51:0] << 1; 
        end else begin
            final_exp = exp_res_pipe[TOTAL_LATENCY];
            final_mant = final_quotient[51:0];
        end
    end
    
    reg [10:0] out_exp;
    reg [51:0] out_mant;
    
    always @(*) begin
        out_exp = final_exp[10:0];
        out_mant = final_mant;
        
        if (final_exp >= 2047) begin // Overflow -> Inf
            out_exp = 11'h7FF;
            out_mant = 52'b0;
        end else if (final_exp <= 0) begin // Underflow -> Denormalized or Zero
            out_mant = ({1'b1, final_mant}) >> (1 - final_exp);
            out_exp = 11'b0;
        end
    end
    
    reg [63:0] result_reg;
    always @(posedge clk) begin
        if (!rst_n) begin
            result_reg <= 64'b0;
        end else begin
            if (special_case_pipe[TOTAL_LATENCY]) begin
                result_reg <= special_result_pipe[TOTAL_LATENCY];
            end else if (out_exp == 0 && out_mant == 0) begin
                result_reg <= {sign_res_pipe[TOTAL_LATENCY], 63'b0};
            end else begin
                result_reg <= {sign_res_pipe[TOTAL_LATENCY], out_exp, out_mant};
            end
        end
    end
    
    assign result = result_reg;

endmodule
