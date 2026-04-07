////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 1995-2008 Xilinx, Inc.  All rights reserved.
////////////////////////////////////////////////////////////////////////////////
//   ____  ____ 
//  /   /\/   / 
// /___/  \  /    Vendor: Xilinx 
// \   \   \/     Version : 10.1
//  \   \         Application : sch2verilog
//  /   /         Filename : alu_64.vf
// /___/   /\     Timestamp : 02/21/2026 17:01:05
// \   \  /  \ 
//  \___\/\___\ 
//
//Command: C:\Xilinx\10.1\ISE\bin\nt\unwrapped\sch2verilog.exe -intstyle ise -family aspartan2e -w Z:/VM_Share/533_lab5/alt_alu64/alu_64.sch alu_64.vf
//Design Name: alu_64
//Device: aspartan2e
//Purpose:
//    This verilog netlist is translated from an ECS schematic.It can be 
//    synthesized and simulated, but it should not be modified. 
//
`timescale 1ns / 1ps

module alu_64(A, 
              ALUOp, 
              B, 
              byte_select, 
              ShiftA, 
              ShiftB, 
              C, 
              N, 
              O, 
              V, 
              Z);

    input [31:0] A;
    input [3:0] ALUOp;
    input [31:0] B;
    input [7:0] byte_select;
    input [6:0] ShiftA;
    input [6:0] ShiftB;
   output C;
   output N;
   output [31:0] O;
   output V;
   output Z;
   
    // Temporary holder for arithmetic value
    reg [32:0] arith_temp;
    
    // Output assignments 

    assign O = arith_temp[31:0];
    assign Z = O == 32'd0 ? 1 : 0;
    assign V = arith_temp[32] != arith_temp[31] ? 1: 0;
    assign C = arith_temp[32];
	 assign N = arith_temp[31];

    always @(*)
    begin
    if (ALUOp == 4'h1)
    begin
        arith_temp = {A[31], A} - {B[31], B};      
    end
    else if (ALUOp == 4'hA)
    begin
        arith_temp = $signed(A) < $signed(B) ? 32'd1 : 32'd0;        
    end
    else
        arith_temp = {A[31], A} + {B[31], B};
   end
  endmodule
