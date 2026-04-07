`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    23:44:22 02/15/2026 
// Design Name: 
// Module Name:    mux8to1_64bitwide 
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
module mux8to1_64bitwide(input [63:0] I0,
							    input [63:0] I1,
							    input [63:0] I2,
							    input [63:0] I3,
							    input [63:0] I4,
							    input [63:0] I5,
							    input [63:0] I6,
							    input [63:0] I7,
								 input S0,
								 input S1,
								 input S2,
								 output reg [63:0] O
    );
	 
wire [2:0] select;
assign select = {S2,S1,S0};

always@(*)
	begin
		case(select)
			3'd0: O = I0;
			3'd1: O = I1;
			3'd2: O = I2;
			3'd3: O = I3;
			3'd4: O = I4;
			3'd5: O = I5;
			3'd6: O = I6;
			3'd7: O = I7;
		endcase
	end


endmodule
