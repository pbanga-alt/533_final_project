`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    21:08:41 05/26/2024 
// Design Name: 
// Module Name:    sign_extend 
// Description:    Sign-extends a 16-bit immediate to 64 bits.
//////////////////////////////////////////////////////////////////////////////////
module sign_extend_GPU(
    input [15:0] in,
    output [63:0] out
);
    assign out = {{48{in[15]}}, in};
endmodule