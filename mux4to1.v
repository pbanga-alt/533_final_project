////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 1995-2008 Xilinx, Inc.  All rights reserved.
////////////////////////////////////////////////////////////////////////////////
//   ____  ____ 
//  /   /\/   / 
// /___/  \  /    Vendor: Xilinx 
// \   \   \/     Version : 10.1
//  \   \         Application : sch2verilog
//  /   /         Filename : mux4to1.vf
// /___/   /\     Timestamp : 02/09/2026 21:07:54
// \   \  /  \ 
//  \___\/\___\ 
//
//Command: C:\Xilinx\10.1\ISE\bin\nt\unwrapped\sch2verilog.exe -intstyle ise -family virtex2p -w "C:/Documents and Settings/student/Syncadder_8bit_schematic/mux4to1.sch" mux4to1.vf
//Design Name: mux4to1
//Device: virtex2p
//Purpose:
//    This verilog netlist is translated from an ECS schematic.It can be 
//    synthesized and simulated, but it should not be modified. 
//
`timescale 1ns / 1ps

module M2_1_MXILINX_mux4to1(D0, 
                            D1, 
                            S0, 
                            O);

    input D0;
    input D1;
    input S0;
   output O;
   
   wire M0;
   wire M1;
   
   AND2B1 I_36_7 (.I0(S0), 
                  .I1(D0), 
                  .O(M0));
   OR2 I_36_8 (.I0(M1), 
               .I1(M0), 
               .O(O));
   AND2 I_36_9 (.I0(D1), 
                .I1(S0), 
                .O(M1));
endmodule
`timescale 1ns / 1ps

module mux4to1(I0, 
               I1, 
               I2, 
               I3, 
               S0, 
               S1, 
               S);

    input I0;
    input I1;
    input I2;
    input I3;
    input S0;
    input S1;
   output S;
   
   wire XLXN_1;
   wire XLXN_2;
   
   M2_1_MXILINX_mux4to1 XLXI_6 (.D0(I0), 
                                .D1(I1), 
                                .S0(S0), 
                                .O(XLXN_1));
   // synthesis attribute HU_SET of XLXI_6 is "XLXI_6_0"
   M2_1_MXILINX_mux4to1 XLXI_7 (.D0(I2), 
                                .D1(I3), 
                                .S0(S0), 
                                .O(XLXN_2));
   // synthesis attribute HU_SET of XLXI_7 is "XLXI_7_1"
   M2_1_MXILINX_mux4to1 XLXI_8 (.D0(XLXN_1), 
                                .D1(XLXN_2), 
                                .S0(S1), 
                                .O(S));
   // synthesis attribute HU_SET of XLXI_8 is "XLXI_8_2"
endmodule
