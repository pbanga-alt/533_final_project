`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    20:27:50 05/26/2024 
// Design Name: 
// Module Name:    control_unit 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description:    A combinational control unit based on a 6-bit opcode.
//                 This design uses dataflow assignments to allow for efficient
//                 synthesis into Look-Up Tables (LUTs).
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module control_unit_GPU (
    input  [5:0] opcode, // Mapped from instruction[31:26]
    output       RegDst,
    output       ALUSrc,
    output       MemtoReg,
    output       RegWrite,
    output       MemRead,
    output       MemWrite,
    output       Beq,
	 output       Bne,
	 output reg [3:0] ALU_Op_Out,
    output       ALUOp1,
    output       ALUOp0,
	 output			IsFP,
	 output			IsACCUM,
	 output			Halt
);

    wire LW                = (opcode == 6'b100011);
    wire SW                = (opcode == 6'b101011);
    wire AddI              = (opcode == 6'b001000);
	 wire ADD_INT 				= (opcode == 6'b000000); 
    wire SUB_INT 				= (opcode == 6'b000001); 
    wire COMP    				= (opcode == 6'b000010); 
    wire SLT     				= (opcode == 6'b000011); 
	 
	 wire ADD_FP  				= (opcode == 6'b000100);
    wire MULT_FP 				= (opcode == 6'b000101);
    wire ReLU    				= (opcode == 6'b000110);
    wire ACCUM   				= (opcode == 6'b000111);
    
    wire BEQ     				= (opcode == 6'b001001); // moved from 000100
    wire BNE    				= (opcode == 6'b001010); // moved from 000101
    wire HALT    				= (opcode == 6'b111111);
	 
	 wire RType_INT = ADD_INT | SUB_INT | COMP | SLT;
    wire RType_FP  = ADD_FP  | MULT_FP | ReLU | ACCUM;
    wire RType_ALL = RType_INT | RType_FP;
	 
    assign RegDst   = RType_ALL; // 1 for Rtype
    assign ALUSrc   = LW | SW | AddI; // 1 for lw/sw/addi
    assign MemtoReg = LW; // 1 for lw
    assign RegWrite = RType_ALL | LW | AddI; // 1 for Rtype/lw/addi
    assign MemRead  = LW; // 1 for lw
    assign MemWrite = SW; // 1 for sw
    assign Beq      = BEQ; // 1 for beq
	 assign Bne      = BNE; // 1 for bne
    assign ALUOp1   = RType_INT; // R-type ALU operation
    assign ALUOp0   = BEQ | BNE; // BEQ ALU operation (subtract)
	 assign IsFP 	  = RType_FP;
	 assign IsACCUM  = ACCUM;
	 assign Halt	  = HALT;
	 
	 // Inside control_unit.v
    // (Make sure ALU_Op_Out is declared as: output reg [3:0] ALU_Op_Out)

    always @(*) begin
        case (opcode)
            // ADD: Math add, or calculating Base+Offset for memory
            6'b100011, 6'b101011, 6'b001000, 6'b000000: ALU_Op_Out = 4'b0000; // LW, SW, AddI, ADD_INT

            // SUB: Math sub, or comparing registers for branch flags
            6'b000001, 6'b001001, 6'b001010:            ALU_Op_Out = 4'b0001; // SUB_INT, BEQ, BNE
            
            // Other R-Type Integer Operations
            6'b000010:                                  ALU_Op_Out = 4'b0010; // COMP
            6'b000011:                                  ALU_Op_Out = 4'b1010; // SLT
            
            // R-Type Floating Point Operations
            6'b000100:                                  ALU_Op_Out = 4'b0100; // ADD_FP
            6'b000101:                                  ALU_Op_Out = 4'b0101; // MULT_FP
            6'b000110:                                  ALU_Op_Out = 4'b0110; // ReLU
            6'b000111:                                  ALU_Op_Out = 4'b0111; // ACCUM
            
            // Safe fallback for HALT (6'b111111) or undefined ops
            default:                                    ALU_Op_Out = 4'b0000; 
        endcase
    end

endmodule