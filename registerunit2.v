`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    12:46:09 02/28/2026 
// Design Name: 
// Module Name:    registerunit2 
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
module registerunit2(
    input rst,
	input clk,
    // From control unit
 //   input [12:0] iteration_ct_in,

    // From decode unit
    input [4:0] rs1_s,
    input [4:0] rs2_s,
    input [4:0] rs3_s,

    // From write back unit
  //  input [3:0] opcode,
   // input [3:0] commit,
    input [4:0] rd_s,
    input [63:0] rd_d,
    input we,
    // To pipeline registers
    output [63:0] rs1_d,
    output [63:0] rs2_d,
    output [63:0] rs3_d
  //  output [3:0] predicate_d
);

// ---------- Local Variables ---------- //
reg [63:0] data_reg [0:15];
//reg [3:0] predicate_reg;

//reg [63:0] new_rd_d;
//reg [15:0] thread0_rd_d, thread1_rd_d, thread2_rd_d, thread3_rd_d;
//reg [3:0] new_predicate_d;
//reg thread0_predicate_d, thread1_predicate_d, thread2_predicate_d, thread3_predicate_d;
//reg [63:0] rs1_d_reg, rs2_d_reg, rs3_d_reg;

//reg [3:0] predicate_d_reg;

assign rs1_d = data_reg[rs1_s[3:0]];
assign rs2_d = data_reg[rs2_s[3:0]];
assign rs3_d = data_reg[rs3_s[3:0]];
//assign predicate_d = predicate_d_reg;
//// ---------- Logic ---------- //

integer i;

always @(posedge clk) begin

  //  if (rst) begin
  //      for (i = 0; i < 22; i=i+1) begin
  //          data_reg[i[3:0]] <= 0;
  //      end 
       // predicate_reg <= 0;
 //   end 
	// else begin
		if(we) data_reg[rd_s[3:0]] <= rd_d;
	//				 end
end


endmodule
