`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    18:30:39 03/08/2026 
// Design Name: 
// Module Name:    tensor_and_memory_wrapper 
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
module tensor_and_memory_wrapper( input clk,
											 input rst,
											 input start,
											 output done,
											 input [11:0] w_a_in,
											 input [11:0] i_a_in,
											 input [11:0] in_count,
											 input [11:0] w_count,
											 input bypass_adder,
											 input bypass_relu
    );

wire [11:0] w_a_from_tensor_to_mem, i_a_from_tensor_to_mem;
wire [63:0] w_data, i_data;
memory mem_inst(.clka(clk),
					 .clkb(clk),
					 .addra(w_a_from_tensor_to_mem),
					 .addrb(i_a_from_tensor_to_mem),
					 .douta(w_data),
					 .doutb(i_data));

tensor_unit tensor(.clk(clk),
						 .rst(rst),
						 .w_a_in(w_a_in),
						 .i_a_in(i_a_in),
						 .start(start),
						 .bypass_adder(bypass_adder),
						 .bypass_relu(bypass_relu),
						 .weight_address(w_a_from_tensor_to_mem),
						 .inputs_address(i_a_from_tensor_to_mem),
						 .input_layer_in(i_data),
						 .weights_in(w_data),
						 .input_count(in_count),
						 .layer_count(w_count),
						 .done(done)
						 );


endmodule
