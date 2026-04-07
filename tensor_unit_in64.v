`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    18:17:09 03/24/2026 
// Design Name: 
// Module Name:    tensor_unit_in64 
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
module tensor_unit_in64(input clk,
						 input rst,
						 input start,
						 //input in_count, // could be hard-coded
						 input [9:0] w_a_in, // from gpu
						 input [9:0] i_a_in, // from gpu
						 output reg [9:0] weight_address,
						 output reg [9:0] inputs_address,
						 output [9:0] intermediate_address,
						 input[63:0] input_layer_in,
						 input[63:0] weights_in,
						 input bypass_adder,
						 input bypass_relu,
						 input [11:0] input_count,
						 input [11:0] layer_count,
						 output reg done,
						 input first_hidden_layer,
						 input final_layer
						
    );
//

assign intermediate_address = done ? weight_address : 10'd0;
reg [63:0] outputs [2:0];
reg [1:0] output_address;
reg [1:0] temp_addr;
wire [63:0] hidden_layer_outputs_out = outputs[temp_addr];;

reg [9:0] overall_counter;
reg [15:0] mac_in;
//wire [11:0] weight_cycles 
parameter START = 4'd0;
parameter MAC = 4'd1;
parameter ADD = 4'd2;
parameter RELU = 4'd3;
parameter WRITE = 4'd4;
parameter DONE = 4'd5;

reg [3:0] state, next_state;
reg local_reset;
wire [15:0] MAC_1_a = mac_in;
wire [15:0] MAC_2_a = mac_in;
wire [15:0] MAC_3_a = mac_in;
wire [15:0] MAC_4_a = mac_in;

wire [15:0] MAC_1_b = weights_in[15:0];
wire [15:0] MAC_2_b = weights_in[31:16];
wire [15:0] MAC_3_b = weights_in[47:32];
wire [15:0] MAC_4_b = weights_in[63:48];

wire [15:0] z_c_1, z_c_2, z_c_3, z_c_4;

MAC_unit_tpu MAC1(.clk(clk),.rst(local_reset),.a_in(MAC_1_a),.b_in(MAC_1_b),.c_in(z_c_1),.z(z_c_1));
MAC_unit_tpu MAC2(.clk(clk),.rst(local_reset),.a_in(MAC_2_a),.b_in(MAC_2_b),.c_in(z_c_2),.z(z_c_2));
MAC_unit_tpu MAC3(.clk(clk),.rst(local_reset),.a_in(MAC_3_a),.b_in(MAC_3_b),.c_in(z_c_3),.z(z_c_3));
MAC_unit_tpu MAC4(.clk(clk),.rst(local_reset),.a_in(MAC_4_a),.b_in(MAC_4_b),.c_in(z_c_4),.z(z_c_4));

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


wire [9:0] weight_incrementation = layer_count >= 4 ? layer_count >>> 2 : 1;
reg [1:0] input_counter;
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
					if (MAC_counter == input_count * 5) begin
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
 
 if(first_hidden_layer) begin
 case(input_counter)
		2'b00: mac_in = input_layer_in[15:0];
		2'b01: mac_in = input_layer_in[31:16];
		2'b10: mac_in = input_layer_in[47:32];
		2'b11: mac_in = input_layer_in[63:48];
		default: mac_in = input_layer_in[15:0];
	 endcase
	 end
	 else begin
		 case(input_counter)
		2'b00: mac_in = hidden_layer_outputs_out[15:0];
		2'b01: mac_in = hidden_layer_outputs_out[31:16];
		2'b10: mac_in = hidden_layer_outputs_out[47:32];
		2'b11: mac_in = hidden_layer_outputs_out[63:48];
		default: mac_in = hidden_layer_outputs_out[15:0];
	 endcase
	 end
end

//reg test;
//reg [1:0] add_counter;
reg [2:0] mul_counter;

always@(posedge clk) begin
 if(rst) begin
   state <= START;
	MAC_counter <= 0;
	
	overall_counter <= 0;
	add_counter <= 0;
	mul_counter <= 0;
	output_address <= 0;
	done <= 1'b0;
	temp_addr <= 0;
//	test <= 0;
 end
 else begin 
	if(start) begin
		state <= next_state;

		if (state == MAC) begin
	
	//	   test <= 1;
			MAC_counter <= MAC_counter + 1;
			mul_counter <= mul_counter + 1;
			if(mul_counter == 3'b011) begin
				//inputs_address <= inputs_address + 1;
		
				weight_address <= weight_address + weight_incrementation;
			end
			if(mul_counter == 3'b100) begin
			mul_counter <= 3'd0;
					input_counter <= input_counter + 1;
		//	in
			end
					if(first_hidden_layer) begin
					if(MAC_counter == input_count * 5) begin
			inputs_address <= inputs_address + 1;
		end
		end
		else begin
			if(MAC_counter == input_count * 5) begin
			temp_addr <= temp_addr + 1;
		end
		end
		end

		if(state == START)  begin
	//		inputs_address <= i_a_in;
		input_counter <= 2'd0;
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
			if(final_layer == 0) outputs[output_address] <= {relu_bypass_mux_out_4,relu_bypass_mux_out_3,relu_bypass_mux_out_2,relu_bypass_mux_out_1};
		   else outputs[output_address] <= {48'd0,relu_bypass_mux_out_1};
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
