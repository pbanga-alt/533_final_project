`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    01:42:15 02/16/2026 
// Design Name: 
// Module Name:    passdecoder 
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
module passdecoder(
							input [3:0] compbits,
							input N,
							input Z,
						   	input V,
							input C,
							output pass
    );

reg pass_reg;

parameter EQ = 4'b0000,
			 NE = 4'b0001,
			 CS = 4'b0010,
			 CC = 4'b0011,
			 MI = 4'b0100,
			 PL = 4'b0101,
			 VS = 4'b0110,
			 VC = 4'b0111,
			 HI = 4'b1000,
			 LS = 4'b1001,
			 GE = 4'b1010,
			 LT = 4'b1011,
			 GTR = 4'b1100,
			 LE = 4'b1101,
			 AL = 4'b1110;
			 
assign pass = pass_reg;

always@(*)
	begin
		case(compbits)
			 EQ: pass_reg = ( Z == 1);
			 NE: pass_reg = ( Z == 0);
			 CS: pass_reg = ( C == 1);
			 CC: pass_reg = ( C == 0);
			 MI: pass_reg = ( N == 1);
			 PL: pass_reg = ( N == 0);
			 VS: pass_reg = ( V == 1);
			 VC: pass_reg = ( V == 0);
			 HI: pass_reg = ( C == 1 && Z == 0);
			 LS: pass_reg = ( C == 0 || Z == 1);
			 GE: pass_reg = ( N == V);
			 LT: pass_reg = ( N != V);
			 GTR: pass_reg = ( Z == 0 && N == V);
			 LE: pass_reg = ( Z == 1 || N != V);
			 AL: pass_reg = 1'b1;
			 default: pass_reg = 1'b0;
		endcase
	end



endmodule
