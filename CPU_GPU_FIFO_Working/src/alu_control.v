`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    21:05:12 05/26/2024 
// Design Name: 
// Module Name:    alu_control 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description:    Decodes the main ALUOp and instruction's function field
//                 to generate the final 4-bit opcode for the 64-bit ALU.
//
// Dependencies:   alu_64.v
//
//////////////////////////////////////////////////////////////////////////////////
module alu_control(
    input [1:0] alu_op_in, // = {ALUOp1, ALUOp0}
    input [3:0] funct,     // = instruction[3:0]
    output reg [3:0] alu_op_out
);
 
     /* ALU Opcode/Instruction type ([1:0]alu_op_in):
	 00 --> Immediate type (lw/sw/addi)
	 01 --> Branch (Beq)
	 10 --> R type
	 11 --> NA
    */
	 
    /* ALU R-type function mapping:
	 0000 --> ADD
	 0001 --> SUB
	 0010 --> COMPARE
	 0011 --> SHIFT & COMPARE
	 0100 --> SUBSTRING COMPARE
	 0101 --> BITWISE OR
	 0110 --> LOGICAL SHIFT (left or write)
	 0111 --> BITWISE XNOR
	 1000 --> BITWISE AND
	 1010 --> SLT
    */
	 
    always @(*)
		begin
			case (alu_op_in)
				2'b00: alu_op_out = 4'b0000; // ADD for LW/SW/ADDI immediate type
				2'b01: alu_op_out = 4'b0001; // SUB for BEQ immediate type
				2'b10: alu_op_out = funct; // R type
				default: alu_op_out = 4'b0000; // default to ADD, not harmful unless its a MemWrite/RegWrite
			endcase
		end
	endmodule
	