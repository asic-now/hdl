// fp64_invsqrt.v
//
// Verilog RTL for 64-bit float inverse square root (1/sqrt(x)).
//
// Features:
// - Refactored to use fp64_classify and an external LUT module.
// - Parameter USE_LUT selects between a LUT-based or combinatorial initial guess.
// - Combinational data path using placeholder FPUs for Newton-Raphson iteration.
//   WARNING: This design is purely combinational and will result in long logic
//            paths. For synthesis, pipelining the N-R stages is recommended.
//
// N-R Iteration: y1 = y0 * (1.5 - (x/2) * y0^2)

module fp64_invsqrt #(
    parameter USE_LUT = 1
) (
    input  [63:0] fp_in,
    output reg [63:0] fp_out
);

    //==================================================================
    // 1. Classification
    //==================================================================
    wire is_snan, is_qnan, is_neg_inf, is_pos_inf, is_neg_norm, is_pos_norm,
         is_neg_denorm, is_pos_denorm, is_neg_zero, is_pos_zero;

    fp64_classify classifier (
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
    wire [63:0] y0_fp;

    generate
        if (USE_LUT == 1) begin : use_lut_guess
            localparam P_LUT = 54;
            wire [P_LUT:0] y0_from_lut;
            wire [10:0] exp_in = fp_in[62:52];
            wire [51:0] mant_in = fp_in[51:0];

            invsqrt_lut_64b lut ( .addr({exp_in[0], mant_in[51:43]}), .data(y0_from_lut) );

            reg [10:0] y0_exp;
            reg [51:0] y0_mant;
            integer shift;
            always @(*) begin
                if (y0_from_lut[P_LUT]) begin
                    y0_exp = 11'd1023;
                    y0_mant = 52'd0;
                end else begin
                    y0_exp = 11'd1022;
                    shift = 0;
                    for (integer i = P_LUT - 1; i >= 0; i = i - 1)
                        if (y0_from_lut[i]) shift = (P_LUT - 1) - i;
                    y0_mant = (y0_from_lut << (shift + 1)) >> (P_LUT - 51);
                end
            end
            assign y0_fp = {1'b0, y0_exp, y0_mant};

        end else begin : use_combinatorial_guess
            localparam [63:0] MAGIC_NUMBER = 64'h5fe6eb50c7b537a9;
            assign y0_fp = MAGIC_NUMBER - (fp_in >> 1);
        end
    endgenerate

    //==================================================================
    // 3. Newton-Raphson Iteration
    //==================================================================
    wire [63:0] x_div2, y0_sq, term, sub_res, y1_fp;
    localparam [63:0] C_1_5 = 64'h3ff8000000000000; // 1.5 in FP64
    localparam [63:0] C_0_5 = 64'h3fe0000000000000; // 0.5 in FP64

    /*
    // TODO: Connect your FPU modules here for the N-R iteration.
    fp64_mul mul_x_div2 (.a(fp_in),   .b(C_0_5),    .result(x_div2)  );
    fp64_mul mul_y0_sq  (.a(y0_fp),   .b(y0_fp),    .result(y0_sq)   );
    fp64_mul mul_term   (.a(x_div2),  .b(y0_sq),    .result(term)    );
    fp64_add sub_res_add(.a(C_1_5),   .b({!term[63], term[62:0]}), .result(sub_res));
    fp64_mul mul_final  (.a(y0_fp),   .b(sub_res),  .result(y1_fp)   );
    */
    
    assign y1_fp = y0_fp; // TEMPORARY BYPASS

    //==================================================================
    // 4. Final Output Selection
    //==================================================================
    always @(*) begin
        if (is_nan || is_invalid_neg) begin
            fp_out = 64'h7FF8000000000001; // qNaN
        end else if (is_pos_inf) begin
            fp_out = 64'h0000000000000000; // +0
        end else if (is_zero) begin
            fp_out = 64'h7FF0000000000000; // +inf
        end else begin
            fp_out = y1_fp;
        end
    end

endmodule
