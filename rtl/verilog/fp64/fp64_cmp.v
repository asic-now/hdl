// fp64_cmp.v
//
// Verilog RTL for a 64-bit (double-precision) floating-point comparator.
//
// Operation: Compares a and b.
//
// Outputs:
// - lt:    1 if a < b
// - eq:    1 if a == b
// - gt:    1 if a > b
// - unord: 1 if a or b is NaN (unordered)
//
// Features:
// - Combinational logic.
// - Handles all special cases: NaN, Infinity, and Zero.

module fp64_cmp (
    input  [63:0] a,
    input  [63:0] b,

    output reg lt,
    output reg eq,
    output reg gt,
    output reg unord
);

    // Unpack inputs a and b
    wire        sign_a = a[63];
    wire [10:0] exp_a  = a[62:52];
    wire [51:0] mant_a = a[51:0];

    wire        sign_b = b[63];
    wire [10:0] exp_b  = b[62:52];
    wire [51:0] mant_b = b[51:0];

    // Detect special values
    wire is_nan_a = (exp_a == 11'h7FF) && (mant_a != 0);
    wire is_nan_b = (exp_b == 11'h7FF) && (mant_b != 0);
    wire is_zero_a = (exp_a == 0) && (mant_a == 0);
    wire is_zero_b = (exp_b == 0) && (mant_b == 0);

    // Determine which has a larger magnitude
    wire mag_a_gt_b = (exp_a > exp_b) || ((exp_a == exp_b) && (mant_a > mant_b));

    always @(*) begin
        // Default all flags to 0
        lt = 1'b0;
        eq = 1'b0;
        gt = 1'b0;
        unord = 1'b0;

        // Case 1: Handle NaNs (Unordered)
        if (is_nan_a || is_nan_b) begin
            unord = 1'b1;
        
        // Case 2: Handle Zeros
        end else if (is_zero_a && is_zero_b) begin
            eq = 1'b1;

        // Case 3: Handle different signs (ignoring zeros)
        end else if (sign_a != sign_b) begin
            if (sign_a == 1'b1) begin // a is negative, b is positive
                lt = 1'b1;
            end else begin // a is positive, b is negative
                gt = 1'b1;
            end

        // Case 4: Handle same signs
        end else begin
            // Check for equality first
            if (exp_a == exp_b && mant_a == mant_b) begin
                eq = 1'b1;
            // Check for magnitude difference
            end else begin
                if (sign_a == 1'b0) begin // Both positive
                    if (mag_a_gt_b) gt = 1'b1;
                    else lt = 1'b1;
                end else begin // Both negative
                    if (mag_a_gt_b) lt = 1'b1; // Larger magnitude means more negative
                    else gt = 1'b1;
                end
            end
        end
    end

endmodule
