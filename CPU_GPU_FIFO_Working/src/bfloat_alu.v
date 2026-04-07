`timescale 1ns / 1ps

// =========================================================================
// LZC Utility (Used in EX2)
// =========================================================================
module lzc_8bit (
    input  wire [7:0] in,
    output wire [2:0] count,
    output wire       all_zero
);
    assign all_zero = (in == 8'b0);
    assign count = in[7] ? 3'd0 : in[6] ? 3'd1 : in[5] ? 3'd2 :
                   in[4] ? 3'd3 : in[3] ? 3'd4 : in[2] ? 3'd5 :
                   in[1] ? 3'd6 : in[0] ? 3'd7 : 3'd0;
endmodule

// =========================================================================
// EX0: FP Multiplier (HEAVY COMPUTE MOVED HERE TO FIX TIMING)
// =========================================================================
module bfloat16_ex0_prep (
    input  wire [15:0] a,
    input  wire [15:0] b,
    output wire        sign_mult,
    output wire [7:0]  final_exp_mult,
    output wire [6:0]  final_sig_mult,
    output wire [15:0] mult_out
);
    assign sign_mult = a[15] ^ b[15];
    wire [8:0] exp_sum_base = {1'b0, a[14:7]} + {1'b0, b[14:7]} - 9'd127;
    
    wire [7:0] sig_a = (|a[14:7]) ? {1'b1, a[6:0]} : 8'b0;
    wire [7:0] sig_b = (|b[14:7]) ? {1'b1, b[6:0]} : 8'b0;

    // The 2.26ns Critical Path is now safely isolated in EX0
    wire [15:0] sig_prod = sig_a * sig_b;
    wire        norm_shift = sig_prod[15];
    
    assign final_sig_mult = norm_shift ? sig_prod[14:8] : sig_prod[13:7];
    assign final_exp_mult = exp_sum_base[7:0] + {7'b0, norm_shift};
    
    // Complete the standalone MULT_FP output in EX0
    assign mult_out = (sig_a == 0 || sig_b == 0) ? 16'b0 : {sign_mult, final_exp_mult, final_sig_mult};
endmodule

module bfloat16_simd64_ex0_prep (
    input  wire [63:0] reg_a, input  wire [63:0] reg_b,
    output wire [3:0]  sign_mult, output wire [31:0] final_exp_mult,
    output wire [27:0] final_sig_mult, output wire [63:0] mult_out
);
    bfloat16_ex0_prep lane0 (.a(reg_a[15:0]),  .b(reg_b[15:0]),  .sign_mult(sign_mult[0]), .final_exp_mult(final_exp_mult[7:0]),   .final_sig_mult(final_sig_mult[6:0]),   .mult_out(mult_out[15:0]));
    bfloat16_ex0_prep lane1 (.a(reg_a[31:16]), .b(reg_b[31:16]), .sign_mult(sign_mult[1]), .final_exp_mult(final_exp_mult[15:8]),  .final_sig_mult(final_sig_mult[13:7]),  .mult_out(mult_out[31:16]));
    bfloat16_ex0_prep lane2 (.a(reg_a[47:32]), .b(reg_b[47:32]), .sign_mult(sign_mult[2]), .final_exp_mult(final_exp_mult[23:16]), .final_sig_mult(final_sig_mult[20:14]), .mult_out(mult_out[47:32]));
    bfloat16_ex0_prep lane3 (.a(reg_a[63:48]), .b(reg_b[63:48]), .sign_mult(sign_mult[3]), .final_exp_mult(final_exp_mult[31:24]), .final_sig_mult(final_sig_mult[27:21]), .mult_out(mult_out[63:48]));
endmodule

// =========================================================================
// EX1: MUX, Compare, and Align (NOW HIGH-SPEED)
// =========================================================================
module bfloat16_ex1_align (
    input  wire        sign_mult_in, input  wire [7:0]  final_exp_mult,
    input  wire [6:0]  final_sig_mult,
    input  wire [15:0] add_op_a,     input  wire [15:0] add_op_b,
    input  wire        is_mac,
    output wire [7:0]  sig_large,    output wire [7:0]  sig_aligned,
    output wire [7:0]  exp_large,    output wire        sign_final,
    output wire        do_sub
);
    // MUX: Select Operand A based on MAC vs ADD_FP
    wire        sign_a = (is_mac & sign_mult_in) | (~is_mac & add_op_a[15]);
    wire [7:0]  exp_a  = is_mac ? final_exp_mult : add_op_a[14:7];
    wire [7:0]  sig_a  = is_mac ? {1'b1, final_sig_mult} : ((|add_op_a[14:7]) ? {1'b1, add_op_a[6:0]} : 8'b0);

    wire        sign_b = add_op_b[15];
    wire [7:0]  exp_b  = add_op_b[14:7];
    wire [7:0]  sig_b  = (|add_op_b[14:7]) ? {1'b1, add_op_b[6:0]} : 8'b0;

    // Compare & Swap
    wire [8:0] exp_diff_calc = {1'b0, exp_a} - {1'b0, exp_b};
    wire exp_a_larger = ~exp_diff_calc[8];
    wire [7:0] exp_diff = exp_a_larger ? exp_diff_calc[7:0] : -exp_diff_calc[7:0];

    wire sig_a_larger = (sig_a >= sig_b);
    wire a_is_larger = (exp_a == exp_b) ? sig_a_larger : exp_a_larger;

    assign exp_large = a_is_larger ? exp_a : exp_b;
    assign sig_large = a_is_larger ? sig_a : sig_b;
    wire [7:0] sig_small = a_is_larger ? sig_b : sig_a;
    assign sign_final = a_is_larger ? sign_a : sign_b;
    
    // Align & Determine Subtraction
    assign sig_aligned = sig_small >> exp_diff;
    assign do_sub = (sign_a ^ sign_b);
endmodule

module bfloat16_simd64_ex1_align (
    input  wire [3:0]  sign_mult_in, input  wire [31:0] final_exp_mult,
    input  wire [27:0] final_sig_mult,
    input  wire [63:0] add_op_a,     input  wire [63:0] add_op_b,
    input  wire        is_mac,
    output wire [31:0] sig_large,    output wire [31:0] sig_aligned,
    output wire [31:0] exp_large,    output wire [3:0]  sign_final,
    output wire [3:0]  do_sub
);
    bfloat16_ex1_align lane0 (.sign_mult_in(sign_mult_in[0]), .final_exp_mult(final_exp_mult[7:0]),   .final_sig_mult(final_sig_mult[6:0]),   .add_op_a(add_op_a[15:0]),  .add_op_b(add_op_b[15:0]),  .is_mac(is_mac), .sig_large(sig_large[7:0]),   .sig_aligned(sig_aligned[7:0]),   .exp_large(exp_large[7:0]),   .sign_final(sign_final[0]), .do_sub(do_sub[0]));
    bfloat16_ex1_align lane1 (.sign_mult_in(sign_mult_in[1]), .final_exp_mult(final_exp_mult[15:8]),  .final_sig_mult(final_sig_mult[13:7]),  .add_op_a(add_op_a[31:16]), .add_op_b(add_op_b[31:16]), .is_mac(is_mac), .sig_large(sig_large[15:8]),  .sig_aligned(sig_aligned[15:8]),  .exp_large(exp_large[15:8]),  .sign_final(sign_final[1]), .do_sub(do_sub[1]));
    bfloat16_ex1_align lane2 (.sign_mult_in(sign_mult_in[2]), .final_exp_mult(final_exp_mult[23:16]), .final_sig_mult(final_sig_mult[20:14]), .add_op_a(add_op_a[47:32]), .add_op_b(add_op_b[47:32]), .is_mac(is_mac), .sig_large(sig_large[23:16]), .sig_aligned(sig_aligned[23:16]), .exp_large(exp_large[23:16]), .sign_final(sign_final[2]), .do_sub(do_sub[2]));
    bfloat16_ex1_align lane3 (.sign_mult_in(sign_mult_in[3]), .final_exp_mult(final_exp_mult[31:24]), .final_sig_mult(final_sig_mult[27:21]), .add_op_a(add_op_a[63:48]), .add_op_b(add_op_b[63:48]), .is_mac(is_mac), .sig_large(sig_large[31:24]), .sig_aligned(sig_aligned[31:24]), .exp_large(exp_large[31:24]), .sign_final(sign_final[3]), .do_sub(do_sub[3]));
endmodule

// =========================================================================
// EX2: FP Add/Sub, LZA, Normalization, FTZ (NO CHANGES)
// =========================================================================
module bfloat16_ex2_norm (
    input  wire [7:0]  sig_large, input  wire [7:0]  sig_aligned, input  wire [7:0]  exp_large,
    input  wire        sign_final, input  wire        do_sub, output wire [15:0] final_out
);
    wire [8:0] sum = do_sub ? (sig_large - sig_aligned) : (sig_large + sig_aligned);

    wire [2:0] lz_count; wire lzc_zero;
    lzc_8bit lzc (.in(sum[7:0]), .count(lz_count), .all_zero(lzc_zero));

    wire true_zero = (sum == 9'b0); 
    wire underflow = (exp_large < lz_count) && !true_zero;

    wire [7:0] exp_final = (sum[8])               ? (exp_large + 1'b1) : 
                           (true_zero | underflow)? 8'b0 :               
                                                    (exp_large - lz_count);

    wire [7:0] normalized_sig = (sum[8]) ? (sum[8:1]) : (sum[7:0] << lz_count);
    
    assign final_out = (true_zero | underflow) ? 16'b0 : {sign_final, exp_final, normalized_sig[6:0]};
endmodule

module bfloat16_simd64_ex2_norm (
    input  wire [31:0] sig_large, input  wire [31:0] sig_aligned, input  wire [31:0] exp_large,
    input  wire [3:0]  sign_final, input  wire [3:0]  do_sub, output wire [63:0] final_out
);
    bfloat16_ex2_norm lane0 (.sig_large(sig_large[7:0]),   .sig_aligned(sig_aligned[7:0]),   .exp_large(exp_large[7:0]),   .sign_final(sign_final[0]), .do_sub(do_sub[0]), .final_out(final_out[15:0]));
    bfloat16_ex2_norm lane1 (.sig_large(sig_large[15:8]),  .sig_aligned(sig_aligned[15:8]),  .exp_large(exp_large[15:8]),  .sign_final(sign_final[1]), .do_sub(do_sub[1]), .final_out(final_out[31:16]));
    bfloat16_ex2_norm lane2 (.sig_large(sig_large[23:16]), .sig_aligned(sig_aligned[23:16]), .exp_large(exp_large[23:16]), .sign_final(sign_final[2]), .do_sub(do_sub[2]), .final_out(final_out[47:32]));
    bfloat16_ex2_norm lane3 (.sig_large(sig_large[31:24]), .sig_aligned(sig_aligned[31:24]), .exp_large(exp_large[31:24]), .sign_final(sign_final[3]), .do_sub(do_sub[3]), .final_out(final_out[63:48]));
endmodule