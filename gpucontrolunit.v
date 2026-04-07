`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    17:42:07 03/09/2026 
// Design Name: 
// Module Name:    gpucontrolunit 
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
module gpucontrolunit(

						input clk,
						input rst,
						input start,
						input ret,
						input [14:0] vec_size,
						output reg [11:0] pc_out,
						output [13:0] current_iteration,
						output [3:0] lane_mask_out,
						output reg done,
						input id_tpu_start,
						input tpu_done,
						input [11:0] if_id_pc_out_reg
		
);

reg [11:0] pc_next;
wire [13:0] iterations_count;
assign iterations_count = {2'b00,vec_size[14:2]};
wire [1:0] remainder;
assign remainder = vec_size[1:0];
reg [13:0] current_iteration_reg;
reg [3:0] lane_mask;
assign current_iteration = current_iteration_reg;
assign lane_mask_out = lane_mask;
wire is_last_iteration = (current_iteration_reg == iterations_count);
//assign done = ret && is_last_iteration;
always@(*) begin
	
	if(!is_last_iteration)
	pc_next = (id_tpu_start & ~tpu_done) ? if_id_pc_out_reg + 1 :  pc_out + 1;

//assign         pc_next = (tpu_start & ~tpu_done) ? if_id_pc_out_reg + 1 :  pc_out + 1;  // Determine next pc


	if(current_iteration_reg == iterations_count-1) begin
	case (remainder)
		2'b01: lane_mask = 4'b0001;
		2'b10: lane_mask = 4'b0011;
		2'b11: lane_mask = 4'b0111;
		default: lane_mask = 4'b1111;
	endcase
	end
	else
		lane_mask = 4'b1111;
end

//reg done_reg;
//assign done = done_reg;
always@(posedge clk) begin
	if(rst) begin
		pc_out <= 16'h0000;
		//lane_mask <= 4'b0000; 
		//iteration = 0;
		current_iteration_reg <= 0;
		done <= 0;
	end
	else begin
		if(start && !(ret&&is_last_iteration)) begin
		pc_out <= pc_next;
		if(start && ret) begin
		current_iteration_reg <= current_iteration_reg + 1;
		pc_out <= 0;
		end
		if (ret && (current_iteration_reg == iterations_count-1)) begin
		//current_iteration_reg <= -1;
		done <= 1;
		end
		end
	end
end



endmodule
