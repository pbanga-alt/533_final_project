`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    19:56:21 02/28/2026 
// Design Name: 
// Module Name:    relu_unit 
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
module relu_unit( input clk, 
		  input rst,
		  input [15:0] a,
		  output reg [15:0] z
    );
wire [15:0] zwire = a[15] ? 16'd0 : a;
//reg [15:0] p1,p2,p3;
always @(posedge clk) begin
	//p1 <= zwire;
	//p2 <= p1;
	//p3 <= p2;
	z <= zwire;
end
endmodule
