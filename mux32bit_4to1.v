////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 1995-2008 Xilinx, Inc.  All rights reserved.
////////////////////////////////////////////////////////////////////////////////
//   ____  ____ 
//  /   /\/   / 
// /___/  \  /    Vendor: Xilinx 
// \   \   \/     Version : 10.1
//  \   \         Application : sch2verilog
//  /   /         Filename : mux32bit_4to1.vf
// /___/   /\     Timestamp : 02/09/2026 21:07:52
// \   \  /  \ 
//  \___\/\___\ 
//
//Command: C:\Xilinx\10.1\ISE\bin\nt\unwrapped\sch2verilog.exe -intstyle ise -family virtex2p -w "C:/Documents and Settings/student/Syncadder_8bit_schematic/mux32bit_4to1.sch" mux32bit_4to1.vf
//Design Name: mux32bit_4to1
//Device: virtex2p
//Purpose:
//    This verilog netlist is translated from an ECS schematic.It can be 
//    synthesized and simulated, but it should not be modified. 
//
`timescale 1ns / 1ps

module mux32bit_4to1(I0, 
                     I1, 
                     I2, 
                     I3, 
                     S0, 
                     S1, 
                     S);

    input [31:0] I0;
    input [31:0] I1;
    input [31:0] I2;
    input [31:0] I3;
    input S0;
    input S1;
   output [31:0] S;
   
   
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
endmodule
