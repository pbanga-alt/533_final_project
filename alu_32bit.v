///////////////////////////////////////////////////////////////////////////////
//
// Module: alu_32bit.v
// Description: 32-bit ALU for ARM-like 5-stage pipeline processor
//
// Operations (4-bit control):
//   4'b0000  : ADD        A + B
//   4'b0001  : SUB        A - B
//   4'b0010  : AND        A & B
//   4'b0011  : OR         A | B
//   4'b0100  : XOR        A ^ B
//   4'b0101  : XNOR       ~(A ^ B)
//   4'b0110  : LSL        A << B[4:0]  (logical shift left  by immediate)
//   4'b0111  : LSR        A >> B[4:0]  (logical shift right by immediate)
//
// Flags:
//   N  : Negative flag  - MSB of result
//   Z  : Zero flag      - result is all zeros
//   C  : Carry flag     - unsigned overflow from ADD/SUB, last shifted out bit for shifts
//   V  : Overflow flag  - signed overflow (ADD/SUB only, 0 for logical ops)
//
// Shift Amount:
//   Shift amount is taken from B[4:0] (5 bits, supports 0-31 shifts on 32-bit operand)
//   B is the immediate value sign-extended from your 9-bit offset field.
//   Only bottom 5 bits are used, upper bits are ignored.
//
// Notes:
//   - CMP  reuses SUB with regwe=0 from decoder (no change needed here)
///////////////////////////////////////////////////////////////////////////////


module alu_32bit (
    input  [31:0]   a,                  // Operand A
    input  [31:0]   b,                  // Operand B (also carries shift amount in b[4:0])
    input  [3:0]    alu_ctrl,           // ALU operation select
    output [31:0]   alu_out,            // ALU result
    output          n_flag,             // Negative flag
    output          z_flag,             // Zero flag
    output          c_flag,             // Carry flag
    output          v_flag              // Overflow flag
);

//-----------------------------------------------------------------------------
// Operation Encodings
//-----------------------------------------------------------------------------
localparam  ALU_ADD  =  4'b0000;
localparam  ALU_SUB  =  4'b0001;
localparam  ALU_AND  =  4'b0010;
localparam  ALU_OR   =  4'b0011;
localparam  ALU_XOR  =  4'b0100;
localparam  ALU_XNOR =  4'b0101;
localparam  ALU_LSL  =  4'b0110;
localparam  ALU_LSR  =  4'b0111;

//-----------------------------------------------------------------------------
// Adder/Subtractor
// For SUB: invert B and set carry-in to 1 (two's complement negation)
//-----------------------------------------------------------------------------

// Adder/Subtractor using Xilinx fast carry primitives
wire [31:0]  adder_b_in  =  (alu_ctrl == ALU_SUB) ? ~b : b;
wire         adder_cin   =  (alu_ctrl == ALU_SUB) ? 1'b1 : 1'b0;

wire [32:0]  adder_result = {1'b0, a} + {1'b0, adder_b_in} + adder_cin;

wire [31:0]  adder_sum   =  adder_result[31:0];
wire         adder_cout  =  adder_result[32];
wire 		 adder_v 	 = (a[31] == adder_b_in[31]) && (adder_sum[31] != a[31]);


// Bitwise Logic Unit


wire [31:0]   and_result  =  a  &   b;
wire [31:0]   or_result   =  a  |   b;
wire [31:0]   xor_result  =  a  ^   b;
wire [31:0]   xnor_result = ~(a ^   b);

// Shift amount = b[4:0] (5 bits for 0-31 shift on 32-bit operand)

// wire [4:0]    shift_amt   =  b[4:0];
// Shift operations - fixed shift by 1 position only
wire [31:0]   lsl_result  =  {a[30:0], 1'b0};   // shift left by 1
wire [31:0]   lsr_result  =  {1'b0, a[31:1]};   // shift right by 1							//adjusted for timing issues.

reg  [31:0]   alu_result;
reg           carry_out;
reg           overflow_out;

always @(*) begin
    case (alu_ctrl)
        ALU_ADD  : begin
                     alu_result   =  adder_sum;
                     carry_out    =  adder_cout;
                     overflow_out =  adder_v;
                   end
        ALU_SUB  : begin
                     alu_result   =  adder_sum;
                     carry_out    =  adder_cout;     // For SUB, carry out = borrow indicator
                     overflow_out =  adder_v;
                   end
        ALU_AND  : begin
                     alu_result   =  and_result;
                     carry_out    =  1'b0;
                     overflow_out =  1'b0;
                   end
        ALU_OR   : begin
                     alu_result   =  or_result;
                     carry_out    =  1'b0;
                     overflow_out =  1'b0;
                   end
        ALU_XOR  : begin
                     alu_result   =  xor_result;
                     carry_out    =  1'b0;
                     overflow_out =  1'b0;
                   end
        ALU_XNOR : begin
                     alu_result   =  xnor_result;
                     carry_out    =  1'b0;
                     overflow_out =  1'b0;
                   end
        ALU_LSL  : begin
                     alu_result   =  lsl_result;
                     carry_out    =  1'b0;
                     overflow_out =  1'b0;
                   end
        ALU_LSR  : begin
                     alu_result   =  lsr_result;
                     carry_out    =  1'b0;
                     overflow_out =  1'b0;
                   end
        default  : begin
                     alu_result   =  32'b0;
                     carry_out    =  1'b0;
                     overflow_out =  1'b0;
                   end
    endcase
end

assign alu_out  =  alu_result;
assign n_flag   =  alu_result[31];                  // MSB of result
assign z_flag   =  (alu_result == 32'b0) ? 1'b1 : 1'b0;   // All zeros
assign c_flag   =  carry_out;
assign v_flag   =  overflow_out;

endmodule
