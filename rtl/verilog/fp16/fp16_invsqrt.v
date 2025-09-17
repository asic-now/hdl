// fp16_invsqrt.v
//
// Verilog RTL for 16-bit float inverse square root (1/sqrt(x)).
//
// Features:
// - Refactored to use fp16_classify and an external LUT module.
// - Parameter USE_LUT selects between a LUT-based or combinatorial initial guess.
// - Combinational data path using placeholder FPUs for Newton-Raphson iteration.
//   WARNING: This design is purely combinational and will result in long logic
//            paths. For synthesis, pipelining the N-R stages is recommended.
//
// N-R Iteration: y1 = y0 * (1.5 - (x/2) * y0^2)

`include "fp16_inc.vh"

module fp16_invsqrt #(
    parameter USE_LUT = 1
) (
    input  [15:0] fp_in,
    output reg [15:0] fp_out
);

    //==================================================================
    // 1. Classification
    //==================================================================
    wire is_snan, is_qnan, is_neg_inf, is_pos_inf, is_neg_norm, is_pos_norm,
         is_neg_denorm, is_pos_denorm, is_neg_zero, is_pos_zero;

    fp16_classify classifier (
        .in(fp_in),
        .is_snan(is_snan), .is_qnan(is_qnan),
        .is_neg_inf(is_neg_inf), .is_pos_inf(is_pos_inf),
        .is_neg_norm(is_neg_norm), .is_pos_norm(is_pos_norm),
        .is_neg_denorm(is_neg_denorm), .is_pos_denorm(is_pos_denorm),
        .is_neg_zero(is_neg_zero), .is_pos_zero(is_pos_zero)
    );

    wire is_nan = is_snan || is_qnan;
    wire is_zero = is_pos_zero || is_neg_zero;
    wire is_invalid_neg = is_neg_norm || is_neg_denorm || is_neg_inf;

    //==================================================================
    // 2. Initial Guess Generation (y0)
    //==================================================================
    wire [15:0] y0_fp;

    generate
        if (USE_LUT == 1) begin : use_lut_guess
            localparam P_LUT = 12; // Internal precision of the LUT output
            wire [P_LUT:0] y0_from_lut;
            wire [4:0] exp_in = fp_in[14:10];
            wire [9:0] mant_in = fp_in[9:0];

            invsqrt_lut_16b lut ( .addr({exp_in[0], mant_in[9:6]}), .data(y0_from_lut) );

            // Convert the fixed-point LUT output (u1.P) to a fp16 float.
            reg [4:0] y0_exp;
            reg [9:0] y0_mant;
            integer shift;
            always @(*) begin
                if (y0_from_lut[P_LUT]) begin // Value is 1.0
                    y0_exp = 5'd15;
                    y0_mant = 10'd0;
                end else begin // Value is < 1.0
                    y0_exp = 5'd14;
                    shift = 0;
                    for (integer i = P_LUT - 1; i >= 0; i = i - 1)
                        if (y0_from_lut[i]) shift = (P_LUT - 1) - i;
                    y0_mant = (y0_from_lut << (shift + 1)) >> (P_LUT - 9);
                end
            end
            assign y0_fp = {1'b0, y0_exp, y0_mant};

        end else begin : use_combinatorial_guess
            localparam [15:0] MAGIC_NUMBER = 16'h5A00;
            assign y0_fp = MAGIC_NUMBER - (fp_in >> 1);
        end
    endgenerate

    //==================================================================
    // 3. Newton-Raphson Iteration
    //==================================================================
    wire [15:0] x_div2, y0_sq, term, sub_res, y1_fp;
    localparam [15:0] C_1_5 = 16'h3E00; // 1.5 in FP16
    localparam [15:0] C_0_5 = 16'h3800; // 0.5 in FP16

    /*
    // TODO: Connect your FPU modules here for the N-R iteration.
    // The logic below requires fp16_mul and fp16_add modules from your library.
    
    fp16_mul mul_x_div2 (.a(fp_in),   .b(C_0_5),    .result(x_div2)  );
    fp16_mul mul_y0_sq  (.a(y0_fp),   .b(y0_fp),    .result(y0_sq)   );
    fp16_mul mul_term   (.a(x_div2),  .b(y0_sq),    .result(term)    );
    fp16_add sub_res_add(.a(C_1_5),   .b({!term[15], term[14:0]}), .result(sub_res));
    fp16_mul mul_final  (.a(y0_fp),   .b(sub_res),  .result(y1_fp)   );
    */
    
    // TEMPORARY BYPASS: Returns initial guess until FPU modules are connected.
    assign y1_fp = y0_fp;

    //==================================================================
    // 4. Final Output Selection
    //==================================================================
    always @(*) begin
        if (is_nan || is_invalid_neg) begin
            fp_out = `FP16_QNAN; // qNaN
        end else if (is_pos_inf) begin
            fp_out = 16'h0000; // 1/sqrt(+inf) -> +0
        end else if (is_zero) begin
            fp_out = 16'h7C00; // 1/sqrt(0) -> +inf
        end else begin
            fp_out = y1_fp;
        end
    end

endmodule
