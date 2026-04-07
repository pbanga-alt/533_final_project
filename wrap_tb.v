`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    16:32:54 03/09/2026 
// Design Name: 
// Module Name:    wrap_tb 
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
module wrap_tb;

reg clk;
reg rst;

wrap dut (.clk(clk),
			 .reset(rst));
			 
initial
	begin
		rst = 1;
		#20
		rst = 0;
	end

initial
	begin
	clk = 0;
	forever
		begin
		 #10 clk = ~clk;
		end
	end

endmodule
