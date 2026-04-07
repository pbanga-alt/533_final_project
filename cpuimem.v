`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    16:20:26 03/09/2026 
// Design Name: 
// Module Name:    cpuimem 
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
module cpuimem(
	addr,
	clk,
	din,
	dout,
	we);


input [8 : 0] addr;
input clk;
input [31 : 0] din;
output [31 : 0] dout;
input we;

// synthesis translate_off

      BLKMEMSP_V6_2 #(
		.c_addr_width(9),
		.c_default_data("0"),
		.c_depth(512),
		.c_enable_rlocs(0),
		.c_has_default_data(1),
		.c_has_din(1),
		.c_has_en(0),
		.c_has_limit_data_pitch(0),
		.c_has_nd(0),
		.c_has_rdy(0),
		.c_has_rfd(0),
		.c_has_sinit(0),
		.c_has_we(1),
		.c_limit_data_pitch(18),
		.c_mem_init_file("imem.mif"),
		.c_pipe_stages(0),
		.c_reg_inputs(0),
		.c_sinit_value("0"),
		.c_width(32),
		.c_write_mode(0),
		.c_ybottom_addr("0"),
		.c_yclk_is_rising(1),
		.c_yen_is_high(1),
		.c_yhierarchy("hierarchy1"),
		.c_ymake_bmm(0),
		.c_yprimitive_type("16kx1"),
		.c_ysinit_is_high(1),
		.c_ytop_addr("1024"),
		.c_yuse_single_primitive(0),
		.c_ywe_is_high(1),
		.c_yydisable_warnings(1))
	inst (
		.ADDR(addr),
		.CLK(clk),
		.DIN(din),
		.DOUT(dout),
		.WE(we),
		.EN(),
		.ND(),
		.RFD(),
		.RDY(),
		.SINIT());


// synthesis translate_on

// XST black box declaration
// box_type "black_box"
// synthesis attribute box_type of imem_32x512_v1 is "black_box"

endmodule
