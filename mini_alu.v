`timescale 1ns / 1ps

module mini_alu (
   input clk,
   input rst,
   input [2:0] func, // 0 = ADD, 1 = SUB, 2 = greater/equal, 3 = max
   input [15:0] a,
   input [15:0] b,
   input [15:0] c,
   output [15:0] out
);

reg [15:0] adder_out;
wire        ge;

wire [15:0] add_out;

wire[15:0] b_neg_or_pos = (func == 1) ? {~b[15],b[14:0]} : b;

bfloat16add adder(.clk(clk),.rst(rst),
			.a(a),
			.b(b_neg_or_pos),
			.out(add_out));

wire[15:0] mult_out;
bfloat16mult multunit(.clk(clk),
	.a(a),.b(b),.out(mult_out));

wire[15:0] tensor_out;
MAC_unit mac(.clk(clk),.rst(rst),.a(a),.b(b),.c(c),.z(tensor_out));

wire [15:0] relu_out;
relu_unit relu_unit(.clk(clk),.rst(rst),.a(a), .z(relu_out));

// Adder/Subtractor
//wire [15:0]  adder_b_in  =  (func == 2'b01) ? ~b : b;
//wire         adder_cin   =  (func == 2'b01) ? 1'b1 : 1'b0;

//wire [16:0]  adder_result = {1'b0, a} + {1'b0, adder_b_in} + adder_cin;

//wire [15:0]  adder_sum   =  adder_result[31:0];
//wire         adder_cout  =  adder_result[32];
//wire 		 adder_overflow = (a[15] == adder_b_in[15]) && (adder_sum[15] != a[15]);


// Comparison logic
//assign ge = $signed(a) >= $signed(b);

reg [2:0] f_s1,f_s2,f_s3,f_s4;

// Output selection
always @(*) begin
    case (f_s4) 
        3'b000 : adder_out = add_out;
        3'b001 : adder_out = add_out;
       // 3'b010 : adder_out = {{15'b0}, ge};
       // 3'b011 : adder_out = (ge) ? a : b;
        3'b100 : adder_out = mult_out;
		  3'b101 : adder_out = relu_out;
		  3'b110 : adder_out = tensor_out;
		  default : adder_out = 16'b0;
    endcase
end

assign out = adder_out;

always@(posedge clk) begin
f_s1 <= func;
f_s2 <= f_s1;
f_s3 <= f_s2;
f_s4 <= f_s3;
end
endmodule
