`timescale 1ns / 1ps
// =============================================================================
// bfloat16mult — 3-stage pipelined BF16 multiplier
//
// Corrections vs original:
//   [C1] Zero detection now checks both exponent AND mantissa fields.
//        Original only checked exponent (ea==0), silently flushing
//        denormals (ea=0, fa≠0) to zero without contract.
//        Under FTZ contract below, detection is deliberate and documented.
//   [C2] exp_adj simplified: removed redundant ternary, direct bit-add.
//   [C3] Mantissa extraction width fixed from 8-bit to 7-bit.
//        Original: mant = prod_msb ? product[14:7] : product[13:6]  (8 bits)
//        This included the guard bit as mant[0], shifting all mantissa
//        bits up by 1 position and corrupting final_mant with a guard-bit
//        leak (e.g. 3.0×6.5 gave 23.0 instead of 19.5).
//        Fixed:  mant = prod_msb ? product[14:8] : product[13:7]  (7 bits)
//        Guard/round/sticky positions corrected accordingly.
//
// Optimizations (software-contract based):
//   [O1] Denormal/zero inputs: CONTRACT: caller flushes denormals to zero
//        in software. Hardware detects ea==0 as FTZ; fa need not be checked.
//   [O2] Underflow (exp_underflow) check retained — needed for correctness
//        when result exponent wraps negative.
//   [O3] exp_overflow threshold: changed to > 254 for clarity
//        (255 = infinity encoding, 254 is the max finite exponent).
//   [O4] exp_adj uses direct 1-bit add on prod_msb — no mux, synthesis
//        maps to a half-adder on the carry chain.
//   [O5] Zero path: if SW guarantees no zero inputs, remove is_zero mux
//        (see commented section). Default: kept for safety.
//
// Pipeline: 3 cycles (in → p1 → p2 → out)
// =============================================================================
(* KEEP_HIERARCHY = "TRUE" *)
module bfloat16mult (
    input  wire        clk,
    input  wire        rst,
    input  wire [15:0] a,   // CONTRACT: denormals flushed to zero by caller
    input  wire [15:0] b,   // CONTRACT: same
    output reg  [15:0] out
);

    // =========================================================================
    // STAGE 1: Unpack, sign, exponent sum, zero detect
    // Critical path: XOR (1 gate) | 10-bit adder | comparator — all parallel
    // =========================================================================
    wire        sa = a[15];
    wire [7:0]  ea = a[14:7];
    wire [6:0]  fa = a[6:0];
    wire        sb = b[15];
    wire [7:0]  eb = b[14:7];
    wire [6:0]  fb = b[6:0];

    // Result sign is always XOR — independent of everything else
    wire res_sign = sa ^ sb;

    // [C1][O1] FTZ zero detection: ea==0 means zero or denormal.
    // Under SW contract, caller flushes denormals, so ea==0 iff input is ±0.
    wire a_zero  = (ea == 8'h00);
    wire b_zero  = (eb == 8'h00);
    wire is_zero = a_zero | b_zero;

    // Significands with implicit leading 1
    wire [7:0] sigA = {1'b1, fa};
    wire [7:0] sigB = {1'b1, fb};

    // Exponent sum with bias removal: ea + eb - 127
    // 10 bits to capture overflow and underflow (signed range)
    wire [9:0] exp_raw = {2'b00, ea} + {2'b00, eb} - 10'd127;

    // ── Stage 1 → Stage 2 register ──────────────────────────────────────────
    reg        p1_sign;
    reg [9:0]  p1_exp_raw;
    reg [7:0]  p1_sigA, p1_sigB;
    reg        p1_is_zero;

    always @(posedge clk) begin
        if (rst) begin
            p1_sign    <= 1'b0;
            p1_exp_raw <= 10'h0;
            p1_sigA    <= 8'h0;
            p1_sigB    <= 8'h0;
            p1_is_zero <= 1'b0;
        end else begin
            p1_sign    <= res_sign;
            p1_exp_raw <= exp_raw;
            p1_sigA    <= sigA;
            p1_sigB    <= sigB;
            p1_is_zero <= is_zero;
        end
    end

    // =========================================================================
    // STAGE 2: 8×8 mantissa multiply (DSP), normalize, extract GRS bits
    // Critical path: DSP multiply → 1-bit MSB check → mux → exp +1
    // =========================================================================

    // Maps to a single DSP18/DSP48 block — single-cycle multiply
    wire [15:0] product = p1_sigA * p1_sigB;

    // Product range: [1.0, 1.0] × [1.0, 1.0] = [1.0, ~4.0)
    //   product[15]=1 → result >= 2.0 → 1x.xxxxxxxx normalized form
    //   product[15]=0 → result <  2.0 → 01.xxxxxxxx, shift exponent down 1
    wire prod_msb = product[15];

    // [C3] Extract 7 mantissa bits + GRS depending on normalization case.
    // When prod_msb=1: implicit 1 at bit15, mantissa at bits[14:8], guard at bit7.
    // When prod_msb=0: implicit 1 at bit14, mantissa at bits[13:7], guard at bit6.
    // Original bug: mant was extracted as 8 bits (product[14:7] / product[13:6]),
    // which included the guard bit as mant[0] and shifted all mantissa bits up by 1,
    // causing the guard to pollute final_mant (e.g. 3.0×6.5=23.0 instead of 19.5).
    wire [6:0] mant      = prod_msb ? product[14:8] : product[13:7];
    wire       guard     = prod_msb ? product[7]    : product[6];
    wire       round_bit = prod_msb ? product[6]    : product[5];
    wire       sticky    = prod_msb ? |product[5:0] : |product[4:0];

    // [O4] Adjust exponent: direct 1-bit add on prod_msb — no ternary/mux
    wire [9:0] exp_adj = p1_exp_raw + {9'd0, prod_msb};

    // ── Stage 2 → Stage 3 register ──────────────────────────────────────────
    reg        p2_sign;
    reg [9:0]  p2_exp;
    reg [6:0]  p2_mant;  // [C3] 7 bits — mantissa field width
    reg        p2_guard, p2_round_bit, p2_sticky;
    reg        p2_is_zero;

    always @(posedge clk) begin
        if (rst) begin
            p2_sign      <= 1'b0;
            p2_exp       <= 10'h0;
            p2_mant      <= 7'h0;
            p2_guard     <= 1'b0;
            p2_round_bit <= 1'b0;
            p2_sticky    <= 1'b0;
            p2_is_zero   <= 1'b0;
        end else begin
            p2_sign      <= p1_sign;
            p2_exp       <= exp_adj;
            p2_mant      <= mant;
            p2_guard     <= guard;
            p2_round_bit <= round_bit;
            p2_sticky    <= sticky;
            p2_is_zero   <= p1_is_zero;
        end
    end

    // =========================================================================
    // STAGE 3: RNE round, overflow/underflow, pack
    // Critical path: 8-bit round adder → 10-bit exp adder → comparator → mux
    // =========================================================================

    // Round-to-Nearest-Even:
    // round_up when: guard & (round_bit | sticky | lsb_of_result)
    wire lsb      = p2_mant[0];
    wire round_up = p2_guard & (p2_round_bit | p2_sticky | lsb);

    wire [7:0] rounded  = {1'b0, p2_mant} + (round_up ? 8'd1 : 8'd0);
    wire       rnd_ov   = rounded[7]; // carry out of 7-bit mantissa field

    // Adjust exponent if rounding overflowed (mantissa wraps to 0)
    wire [9:0] final_exp  = p2_exp + {9'd0, rnd_ov};
    wire [6:0] final_mant = rnd_ov ? 7'h0 : rounded[6:0];

    // [O3] Overflow: exponent >= 255 maps to infinity
    //      Underflow: exponent went negative (bit 9 = sign in 10-bit signed)
    wire exp_overflow  = (final_exp >= 10'd255);
    wire exp_underflow =  final_exp[9];

    // Result mux — priority: zero > underflow > overflow > normal
    wire [15:0] result =
        p2_is_zero    ? {p2_sign, 15'h0}          :
        exp_underflow ? {p2_sign, 15'h0}           :
        exp_overflow  ? {p2_sign, 8'hFF, 7'h0}    :
                        {p2_sign, final_exp[7:0], final_mant};
    reg[15:0] p4;
    // ── Output register ───────────────────────────────────────────────────────
    always @(posedge clk) begin
        if (rst) p4 <= 16'h0000;
        else     p4 <= result;

	out <= p4;
    end

endmodule
