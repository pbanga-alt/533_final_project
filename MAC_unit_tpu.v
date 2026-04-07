`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    15:40:52 03/24/2026 
// Design Name: 
// Module Name:    MAC_unit_tpu 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module MAC_unit_tpu(
     input  wire        clk,
    input  wire        rst,
    input  wire [15:0] a_in,
    input  wire [15:0] b_in,
    input  wire [15:0] c_in,
    output reg  [15:0] z
);

reg [15:0] a,b,c;
	always@(posedge clk) begin
		if(rst) begin
			a <= 16'd0;
			b <= 16'd0;
			c <= 16'd0;
		end
		else begin
		a <= a_in;
		b <= b_in;
		c <= c_in;
		end
	end
    // =========================================================
    // STAGE 1: Unpack, sign, exponent arithmetic, zero detect
    // =========================================================
    wire        sa = a[15]; wire [7:0] ea = a[14:7]; wire [6:0] fa = a[6:0];
    wire        sb = b[15]; wire [7:0] eb = b[14:7]; wire [6:0] fb = b[6:0];
    wire        sc = c[15]; wire [7:0] ec = c[14:7]; wire [6:0] fc = c[6:0];

    wire prod_sign = sa ^ sb;
    wire ab_zero   = (ea == 8'h00) | (eb == 8'h00);

    wire [7:0] sigA = {1'b1, fa};
    wire [7:0] sigB = {1'b1, fb};
    wire [7:0] sigC = {(ec != 8'h0), fc};

    // Product exponent: ea + eb - 127.  897 = -127 mod 2^10.
    wire [9:0] prod_exp     = {2'b00, ea} + {2'b00, eb} + 10'd897;
    wire       prod_exp_neg = prod_exp[9];

    // Alignment difference.
    wire [10:0] diff_pe  = {1'b0, prod_exp} - {3'b000, ec};
    wire        diff_neg = prod_exp_neg | diff_pe[10];

    wire [10:0] diff_abs = prod_exp_neg ? 11'd20 :
                           diff_pe[10]  ? (~diff_pe + 11'd1) : diff_pe;

    wire        large_shift  = |diff_abs[10:5] | (diff_abs[4] & |diff_abs[3:2]);
    wire [4:0]  shift_amt    = large_shift ? 5'd20 : diff_abs[4:0];

    // result_exp: base exponent (adj for prod_msb applied in Stage 2).
    wire [9:0] result_exp_s1 = diff_neg ? {2'b00, ec} : prod_exp;

    // shift_amt_m1: shift amount pre-adjusted for prod_msb=1.
    // Computed here on settled signals; Stage 2 just muxes on prod_msb.
    wire [4:0] shift_amt_m1 = diff_neg
        ? (shift_amt > 5'd0  ? shift_amt - 5'd1 : 5'd0)
        : (shift_amt < 5'd20 ? shift_amt + 5'd1 : 5'd20);

    // ---- Stage 1->2 registers (64 bits) ----------------------
    reg [7:0]  p1_sigA, p1_sigB, p1_sigC;
    reg        p1_prod_sign, p1_sc;
    reg [9:0]  p1_result_exp;
    reg [4:0]  p1_shift_amt, p1_shift_amt_m1;
    reg        p1_diff_neg;
    reg        p1_ab_zero;
    reg [15:0] p1_c_value;

    always @(posedge clk) begin
        if (rst) begin
            p1_sigA        <= 0; p1_sigB         <= 0; p1_sigC         <= 0;
            p1_prod_sign   <= 0; p1_sc            <= 0;
            p1_result_exp  <= 0;
            p1_shift_amt   <= 0; p1_shift_amt_m1 <= 0; p1_diff_neg    <= 0;
            p1_ab_zero     <= 0; p1_c_value       <= 0;
        end else begin
            p1_sigA        <= sigA;        p1_sigB        <= sigB;
            p1_sigC        <= sigC;        p1_prod_sign   <= prod_sign;
            p1_sc          <= sc;          p1_result_exp  <= result_exp_s1;
            p1_shift_amt   <= shift_amt;   p1_shift_amt_m1<= shift_amt_m1;
            p1_diff_neg    <= diff_neg;    p1_ab_zero     <= ab_zero;
            p1_c_value     <= c;
        end
    end

    // =========================================================
    // STAGE 2: Multiply + alignment shift + sticky
    // =========================================================

    (* use_dsp48 = "yes" *) wire [15:0] product = p1_sigA * p1_sigB;

    // prod_msb kept as a buffered node -- only drives two 1-bit muxes below.
    (* KEEP = "TRUE" *) wire prod_msb = product[15];

    // Speculative prod_ext: both shifts pre-computed; prod_msb selects final result.
    wire [19:0] prod_ext_1 = {product[15:0], 4'b0};
    wire [19:0] prod_ext_0 = {product[14:0], 5'b0};
    wire [19:0] prod_ext   = prod_msb ? prod_ext_1 : prod_ext_0;

    wire [19:0] c_ext = {p1_sigC, 12'b0};

    // true_shift: single 1-bit mux; no +-1 logic here.
    wire [4:0] true_shift = prod_msb ? p1_shift_amt_m1 : p1_shift_amt;

    // adj_exp: result_exp + prod_msb.  Correct because p1_result_exp = prod_exp
    // when !diff_neg (the only time adj_exp feeds p2_result_exp).
    wire [9:0] adj_exp = p1_result_exp + {9'd0, prod_msb};

    // Barrel shifter with per-stage sticky.
    // Each true_shift[i] bit has fanout=2 (shifter mux + 1-bit AND for sticky).
    wire [19:0] to_shift = p1_diff_neg ? prod_ext : c_ext;

    wire [19:0] sh1 = true_shift[0] ? {1'b0,    to_shift[19:1]} : to_shift;
    wire        sk1 = true_shift[0] & to_shift[0];

    wire [19:0] sh2 = true_shift[1] ? {2'b00,   sh1[19:2]}      : sh1;
    wire        sk2 = true_shift[1] & |sh1[1:0];

    wire [19:0] sh3 = true_shift[2] ? {4'b0,    sh2[19:4]}      : sh2;
    wire        sk3 = true_shift[2] & |sh2[3:0];

    wire [19:0] sh4 = true_shift[3] ? {8'b0,    sh3[19:8]}      : sh3;
    wire        sk4 = true_shift[3] & |sh3[7:0];

    wire [19:0] shifted  = true_shift[4] ? {16'b0, sh4[19:16]}  : sh4;
    wire        sk5      = true_shift[4] & |sh4[15:0];

    wire sticky_out = sk1 | sk2 | sk3 | sk4 | sk5;

    wire [19:0] prod_final = p1_diff_neg ? shifted  : prod_ext;
    wire [19:0] c_final    = p1_diff_neg ? c_ext    : shifted;

    // result_exp for Stage 3.
    wire [9:0] result_exp_s2 = p1_diff_neg ? p1_result_exp : adj_exp;

    // ---- Stage 2->3 registers (70 bits) ----------------------
    reg [19:0] p2_prod_final, p2_c_final;
    reg        p2_sticky;
    reg [9:0]  p2_result_exp;
    reg        p2_prod_sign, p2_sc;
    reg        p2_ab_zero;
    reg [15:0] p2_c_value;

    always @(posedge clk) begin
        if (rst) begin
            p2_prod_final <= 0; p2_c_final    <= 0; p2_sticky    <= 0;
            p2_result_exp <= 0; p2_prod_sign  <= 0; p2_sc        <= 0;
            p2_ab_zero    <= 0; p2_c_value    <= 0;
        end else begin
            p2_prod_final <= prod_final;  p2_c_final    <= c_final;
            p2_sticky     <= sticky_out;  p2_result_exp <= result_exp_s2;
            p2_prod_sign  <= p1_prod_sign; p2_sc        <= p1_sc;
            p2_ab_zero    <= p1_ab_zero;  p2_c_value    <= p1_c_value;
        end
    end

    // =========================================================
    // STAGE 3: Add/subtract + sign + LZC + coarse shift + speculative norm_e
    // =========================================================

    wire same_sign = (p2_prod_sign == p2_sc);

    wire [20:0] sum_res = {1'b0, p2_prod_final} + {1'b0, p2_c_final};

    // Dual subtractors: sub_pos[20] is the sign bit.
    // Eliminates the separate 20-bit ripple comparator from the critical path.
    wire [20:0] sub_pos   = {1'b0, p2_prod_final} - {1'b0, p2_c_final};
    wire [20:0] sub_neg   = {1'b0, p2_c_final}    - {1'b0, p2_prod_final};
    wire        prod_ge_c = ~sub_pos[20];
    wire [20:0] sub_res   = prod_ge_c ? sub_pos : sub_neg;

    wire [20:0] mag       = same_sign ? sum_res : sub_res;

    wire res_sign_s3  = same_sign ? p2_prod_sign :
                        prod_ge_c ? p2_prod_sign : p2_sc;

    wire result_zero_s3 = (mag == 21'h0);
    wire add_ov_s3      = mag[20];
    wire [20:0] mag_ov_adj = add_ov_s3 ? {1'b0, mag[20:1]} : mag;

    // Coarse LZC (3-band: 0, 8, 16).
    wire any_hi  = |mag_ov_adj[20:13];
    wire any_mid = |mag_ov_adj[12:5];

    wire cs0 =  any_hi;
    wire cs1 = ~any_hi &  any_mid;
    wire cs2 = ~any_hi & ~any_mid;

    wire [20:0] coarse_shifted =
        cs0 ? mag_ov_adj                 :
        cs1 ? {mag_ov_adj[12:0], 8'b0}  :
              {mag_ov_adj[4:0],  16'b0} ;

    // Fine LZC: 3-bit priority encoder, 3 parallel paths selected by cs0/cs1/cs2.
    wire [2:0] lzc_fine =
        cs0 ? (mag_ov_adj[20] ? 3'd0 : mag_ov_adj[19] ? 3'd1 :
               mag_ov_adj[18] ? 3'd2 : mag_ov_adj[17] ? 3'd3 :
               mag_ov_adj[16] ? 3'd4 : mag_ov_adj[15] ? 3'd5 :
               mag_ov_adj[14] ? 3'd6 : 3'd7) :
        cs1 ? (mag_ov_adj[12] ? 3'd0 : mag_ov_adj[11] ? 3'd1 :
               mag_ov_adj[10] ? 3'd2 : mag_ov_adj[9]  ? 3'd3 :
               mag_ov_adj[8]  ? 3'd4 : mag_ov_adj[7]  ? 3'd5 :
               mag_ov_adj[6]  ? 3'd6 : 3'd7) :
              (mag_ov_adj[4]  ? 3'd0 : mag_ov_adj[3]  ? 3'd1 :
               mag_ov_adj[2]  ? 3'd2 : mag_ov_adj[1]  ? 3'd3 :
               mag_ov_adj[0]  ? 3'd4 : 3'd5);

    // Speculative norm_e: three parallel bases, all from registered p2_result_exp.
    // norm_e_c0 also serves the add_ov path (both = result_exp+1).
    wire [9:0] norm_e_c0 = p2_result_exp + 10'd1;   // coarse=0 and add_ov
    wire [9:0] norm_e_c1 = p2_result_exp - 10'd7;   // coarse=8
    wire [9:0] norm_e_c2 = p2_result_exp - 10'd15;  // coarse=16

    // ---- Stage 3->4 registers (77 bits) ----------------------
    reg [20:0] p3_coarse;
    reg [2:0]  p3_lzc_fine;
    reg [9:0]  p3_norm_e_c0, p3_norm_e_c1, p3_norm_e_c2;
    reg        p3_add_ov, p3_cs1, p3_cs2;
    reg        p3_sign, p3_sticky;
    reg        p3_ab_zero, p3_result_zero;
    reg [15:0] p3_c_value;

    always @(posedge clk) begin
        if (rst) begin
            p3_coarse      <= 0; p3_lzc_fine    <= 0;
            p3_norm_e_c0   <= 0; p3_norm_e_c1   <= 0; p3_norm_e_c2  <= 0;
            p3_add_ov      <= 0; p3_cs1         <= 0; p3_cs2        <= 0;
            p3_sign        <= 0; p3_sticky      <= 0;
            p3_ab_zero     <= 0; p3_result_zero <= 0; p3_c_value    <= 0;
        end else begin
            p3_coarse      <= coarse_shifted;  p3_lzc_fine   <= lzc_fine;
            p3_norm_e_c0   <= norm_e_c0;       p3_norm_e_c1  <= norm_e_c1;
            p3_norm_e_c2   <= norm_e_c2;       p3_add_ov     <= add_ov_s3;
            p3_cs1         <= cs1;             p3_cs2        <= cs2;
            p3_sign        <= res_sign_s3;     p3_sticky     <= p2_sticky;
            p3_ab_zero     <= p2_ab_zero;      p3_result_zero<= result_zero_s3;
            p3_c_value     <= p2_c_value;
        end
    end

    // =========================================================
    // STAGE 4: Fine shift + norm_e finalize + round + pack
    // =========================================================

    wire [20:0] fs1    = p3_lzc_fine[0] ? {p3_coarse[19:0], 1'b0} : p3_coarse;
    wire [20:0] fs2    = p3_lzc_fine[1] ? {fs1[18:0],       2'b0} : fs1;
    wire [20:0] norm_m = p3_lzc_fine[2] ? {fs2[16:0],       4'b0} : fs2;

    // Select norm_e base; p3_norm_e_c0 covers both cs0 and add_ov (same formula).
    wire [9:0] norm_e_base =
        p3_cs1 ? p3_norm_e_c1 :
        p3_cs2 ? p3_norm_e_c2 :
                 p3_norm_e_c0;

    wire [9:0] norm_e = p3_add_ov ? norm_e_base
                                   : (norm_e_base - {7'b0, p3_lzc_fine});

    wire [6:0] mant7    = norm_m[19:13];
    wire       g_bit    = norm_m[12];
    wire       r_bit    = norm_m[11];
    wire       s_bit    = |norm_m[10:0] | p3_sticky;

    wire       round_up = g_bit & (r_bit | s_bit | mant7[0]);
    wire [7:0] rounded  = {1'b0, mant7} + {7'b0, round_up};
    wire       rnd_ov   = rounded[7];

    wire [9:0] final_e = norm_e + {9'b0, rnd_ov};
    wire [6:0] final_m = rnd_ov ? 7'h0 : rounded[6:0];

    wire exp_ov = (final_e >= 10'd255);
    wire exp_un =  final_e[9];

    wire [15:0] result =
        p3_result_zero ? {p3_sign, 15'h0}       :
        p3_ab_zero     ? p3_c_value              :
        exp_un         ? {p3_sign, 15'h0}        :
        exp_ov         ? {p3_sign, 8'hFF, 7'h0} :
                         {p3_sign, final_e[7:0], final_m};

    always @(posedge clk) begin
        if (rst) z <= 16'h0;
        else     z <= result;
    end

endmodule

