`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    00:15:04 03/06/2026 
// Design Name: 
// Module Name:    tensor_unit 
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
module tensor_unit(input clk,
						 input rst,
						 input start,
						 //input in_count, // could be hard-coded
						 input [9:0] w_a_in, // from gpu
						 input [9:0] i_a_in, // from gpu
						 output reg [9:0] weight_address,
						 output reg [9:0] inputs_address,
						 input[63:0] input_layer_in,
						 input[63:0] weights_in,
						 input bypass_adder,
						 input bypass_relu,
						 //input[15:0] a1,
						 //input[15:0] b1,
						 //input[15:0] a2,
						 //input[15:0] b2,
						 //input[15:0] a3,
						 //input[15:0] b3,
						 input [11:0] input_count,
						 input [11:0] layer_count,
						 output reg done
						
    );
//
reg [63:0] outputs [2:0];
reg [1:0] output_address;

reg [9:0] overall_counter;

//wire [11:0] weight_cycles 
parameter START = 4'd0;
parameter MAC = 4'd1;
parameter ADD = 4'd2;
parameter RELU = 4'd3;
parameter WRITE = 4'd4;
parameter DONE = 4'd5;

reg [3:0] state, next_state;
reg local_reset;
wire [15:0] MAC_1_a = input_layer_in[15:0];
wire [15:0] MAC_2_a = input_layer_in[15:0];
wire [15:0] MAC_3_a = input_layer_in[15:0];
wire [15:0] MAC_4_a = input_layer_in[15:0];

wire [15:0] MAC_1_b = weights_in[15:0];
wire [15:0] MAC_2_b = weights_in[31:16];
wire [15:0] MAC_3_b = weights_in[47:32];
wire [15:0] MAC_4_b = weights_in[63:48];

wire [15:0] z_c_1, z_c_2, z_c_3, z_c_4;

MAC_unit MAC1(.clk(clk),.rst(local_reset),.a(MAC_1_a),.b(MAC_1_b),.c(z_c_1),.z(z_c_1));
MAC_unit MAC2(.clk(clk),.rst(local_reset),.a(MAC_2_a),.b(MAC_2_b),.c(z_c_2),.z(z_c_2));
MAC_unit MAC3(.clk(clk),.rst(local_reset),.a(MAC_3_a),.b(MAC_3_b),.c(z_c_3),.z(z_c_3));
MAC_unit MAC4(.clk(clk),.rst(local_reset),.a(MAC_4_a),.b(MAC_4_b),.c(z_c_4),.z(z_c_4));

wire [15:0] add_out_1, add_out_2, add_out_3, add_out_4;

bfloat16add add1(.clk(clk), .rst(rst), .a(z_c_1), .b(MAC_1_b), .out(add_out_1));
bfloat16add add2(.clk(clk), .rst(rst), .a(z_c_2), .b(MAC_2_b), .out(add_out_2));
bfloat16add add3(.clk(clk), .rst(rst), .a(z_c_3), .b(MAC_3_b), .out(add_out_3));
bfloat16add add4(.clk(clk), .rst(rst), .a(z_c_4), .b(MAC_4_b), .out(add_out_4));

wire [15:0] add_bypass_mux_out_1 = bypass_adder ? z_c_1 : add_out_1;
wire [15:0] add_bypass_mux_out_2 = bypass_adder ? z_c_2 : add_out_2;
wire [15:0] add_bypass_mux_out_3 = bypass_adder ? z_c_3 : add_out_3;
wire [15:0] add_bypass_mux_out_4 = bypass_adder ? z_c_4 : add_out_4;

wire [15:0] relu_out_1, relu_out_2, relu_out_3, relu_out_4;

relu_unit relu1(.clk(clk), .rst(rst), .a(add_bypass_mux_out_1), .z(relu_out_1));
relu_unit relu2(.clk(clk), .rst(rst), .a(add_bypass_mux_out_2), .z(relu_out_2));
relu_unit relu3(.clk(clk), .rst(rst), .a(add_bypass_mux_out_3), .z(relu_out_3));
relu_unit relu4(.clk(clk), .rst(rst), .a(add_bypass_mux_out_4), .z(relu_out_4));

wire [15:0] relu_bypass_mux_out_1 = bypass_relu ? add_bypass_mux_out_1 : relu_out_1;
wire [15:0] relu_bypass_mux_out_2 = bypass_relu ? add_bypass_mux_out_2 : relu_out_2;
wire [15:0] relu_bypass_mux_out_3 = bypass_relu ? add_bypass_mux_out_3 : relu_out_3;
wire [15:0] relu_bypass_mux_out_4 = bypass_relu ? add_bypass_mux_out_4 : relu_out_4;

reg [15:0] MAC_counter;
reg [1:0] add_counter;


wire [9:0] weight_incrementation = layer_count >>> 2;

always@(*) begin
 case(state)
    START: begin
	            local_reset = 1'b1;
					if(start)
						begin
						next_state = MAC;
						
						end
				end
	  MAC: begin
	    			local_reset = 1'b0;
					if (MAC_counter == input_count * 4) begin
					if(bypass_adder && bypass_relu) next_state = WRITE;
					else if(bypass_adder) next_state = RELU;
					else next_state = ADD;
					end
					else next_state = MAC;
			  end
	  ADD: begin
	    			local_reset = 1'b0;
					if(add_counter == 2'b11) begin
					if(bypass_relu) next_state = WRITE;
					else next_state = RELU;
				end
				else next_state = ADD;
			  end
	   RELU: begin
				local_reset = 1'b0;
	       	next_state = WRITE;
				end
		WRITE: begin
					if(overall_counter == weight_incrementation - 1) next_state = DONE;
					else next_state = START;
				 end
				 
		DONE: begin
			//	done = 1;
				next_state = DONE;
				end
		 default: begin
		 	    			local_reset = 1'b0;
							next_state = state;
						//	done = 0;
							end
 endcase
end

//reg test;
//reg [1:0] add_counter;
reg [1:0] mul_counter;
always@(posedge clk) begin
 if(rst) begin
   state <= START;
	MAC_counter <= 0;
	
	overall_counter <= 0;
	add_counter <= 0;
	mul_counter <= 0;
	output_address <= 0;
	done <= 1'b0;
//	test <= 0;
 end
 else begin 
	if(start) begin
		state <= next_state;

		if (state == MAC) begin
	//	   test <= 1;
			MAC_counter <= MAC_counter + 1;
			mul_counter <= mul_counter + 1;
			if(mul_counter == 2'b10) begin
				inputs_address <= inputs_address + 1;
				weight_address <= weight_address + weight_incrementation;
			end
		end
		if(state == START) begin
	//		inputs_address <= i_a_in;
	//		test <= 1;
	//		weight_address <= w_a_in + overall_counter;
			end
		if(state == DONE) begin
			done <= 1'b1;
			end
		if(state == ADD) begin
	//	   test <= 0;
			MAC_counter <= 0;
			mul_counter <= 0;
			add_counter <= add_counter + 1;
		end
		if(state == WRITE) begin
			output_address <= output_address + 1;
			overall_counter <= overall_counter + 1;
			outputs[output_address] <= {relu_bypass_mux_out_4,relu_bypass_mux_out_3,relu_bypass_mux_out_2,relu_bypass_mux_out_1};
		   if (overall_counter != weight_incrementation - 1) begin
						inputs_address <= i_a_in;
				//		test <= 1;
				weight_address <= w_a_in + overall_counter + 1;
			end
		end
	end
	else begin
	 inputs_address <= i_a_in;
    weight_address <= w_a_in;
	end
 end
end


endmodule
