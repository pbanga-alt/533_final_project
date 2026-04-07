////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 1995-2008 Xilinx, Inc.  All rights reserved.
////////////////////////////////////////////////////////////////////////////////
//   ____  ____ 
//  /   /\/   / 
// /___/  \  /    Vendor: Xilinx 
// \   \   \/     Version : 10.1
//  \   \         Application : sch2verilog
//  /   /         Filename : mux4to1_64bit.vf
// /___/   /\     Timestamp : 02/12/2026 17:35:27
// \   \  /  \ 
//  \___\/\___\ 
//
//Command: C:\Xilinx\10.1\ISE\bin\nt\unwrapped\sch2verilog.exe -intstyle ise -family virtex2p -w "C:/Documents and Settings/student/registerfile/mux4to1_64bit.sch" mux4to1_64bit.vf
//Design Name: mux4to1_64bit
//Device: virtex2p
//Purpose:
//    This verilog netlist is translated from an ECS schematic.It can be 
//    synthesized and simulated, but it should not be modified. 
//
`timescale 1ns / 1ps

module mux4to1_64bit(I0, 
                     I1, 
                     I2, 
                     I3, 
                     S0, 
                     S1, 
                     S);

    input [63:0] I0;
    input [63:0] I1;
    input [63:0] I2;
    input [63:0] I3;
    input S0;
    input S1;
   output [63:0] S;
   
   
   mx8 XLXI_5 (.I0(I0[7:0]), 
               .I1(I1[7:0]), 
               .I2(I2[7:0]), 
               .I3(I3[7:0]), 
               .S0(S0), 
               .S1(S1), 
               .S(S[7:0]));
   mx8 XLXI_6 (.I0(I0[31:24]), 
               .I1(I1[31:24]), 
               .I2(I2[31:24]), 
               .I3(I3[31:24]), 
               .S0(S0), 
               .S1(S1), 
               .S(S[31:24]));
   mx8 XLXI_7 (.I0(I0[23:16]), 
               .I1(I1[23:16]), 
               .I2(I2[23:16]), 
               .I3(I3[23:16]), 
               .S0(S0), 
               .S1(S1), 
               .S(S[23:16]));
   mx8 XLXI_8 (.I0(I0[15:8]), 
               .I1(I1[15:8]), 
               .I2(I2[15:8]), 
               .I3(I3[15:8]), 
               .S0(S0), 
               .S1(S1), 
               .S(S[15:8]));
   mx8 XLXI_9 (.I0(I0[47:40]), 
               .I1(I1[47:40]), 
               .I2(I2[47:40]), 
               .I3(I3[47:40]), 
               .S0(S0), 
               .S1(S1), 
               .S(S[47:40]));
   mx8 XLXI_10 (.I0(I0[55:48]), 
                .I1(I1[55:48]), 
                .I2(I2[55:48]), 
                .I3(I3[55:48]), 
                .S0(S0), 
                .S1(S1), 
                .S(S[55:48]));
   mx8 XLXI_11 (.I0(I0[63:56]), 
                .I1(I1[63:56]), 
                .I2(I2[63:56]), 
                .I3(I3[63:56]), 
                .S0(S0), 
                .S1(S1), 
                .S(S[63:56]));
   mx8 XLXI_12 (.I0(I0[39:32]), 
                .I1(I1[39:32]), 
                .I2(I2[39:32]), 
                .I3(I3[39:32]), 
                .S0(S0), 
                .S1(S1), 
                .S(S[39:32]));
endmodule
