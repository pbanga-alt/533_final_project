////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 1995-2008 Xilinx, Inc.  All rights reserved.
////////////////////////////////////////////////////////////////////////////////
//   ____  ____ 
//  /   /\/   / 
// /___/  \  /    Vendor: Xilinx 
// \   \   \/     Version : 10.1
//  \   \         Application : sch2verilog
//  /   /         Filename : regfile_8.vf
// /___/   /\     Timestamp : 02/16/2026 00:07:40
// \   \  /  \ 
//  \___\/\___\ 
//
//Command: C:\Xilinx\10.1\ISE\bin\nt\unwrapped\sch2verilog.exe -intstyle ise -family virtex2p -w "C:/Documents and Settings/student/registerfile/regfile_8.sch" regfile_8.vf
//Design Name: regfile_8
//Device: virtex2p
//Purpose:
//    This verilog netlist is translated from an ECS schematic.It can be 
//    synthesized and simulated, but it should not be modified. 
//
`timescale 1ns / 1ps

module D3_8E_MXILINX_regfile_8(A0, 
                               A1, 
                               A2, 
                               E, 
                               D0, 
                               D1, 
                               D2, 
                               D3, 
                               D4, 
                               D5, 
                               D6, 
                               D7);

    input A0;
    input A1;
    input A2;
    input E;
   output D0;
   output D1;
   output D2;
   output D3;
   output D4;
   output D5;
   output D6;
   output D7;
   
   
   AND4 I_36_30 (.I0(A2), 
                 .I1(A1), 
                 .I2(A0), 
                 .I3(E), 
                 .O(D7));
   AND4B1 I_36_31 (.I0(A0), 
                   .I1(A2), 
                   .I2(A1), 
                   .I3(E), 
                   .O(D6));
   AND4B1 I_36_32 (.I0(A1), 
                   .I1(A2), 
                   .I2(A0), 
                   .I3(E), 
                   .O(D5));
   AND4B2 I_36_33 (.I0(A1), 
                   .I1(A0), 
                   .I2(A2), 
                   .I3(E), 
                   .O(D4));
   AND4B1 I_36_34 (.I0(A2), 
                   .I1(A0), 
                   .I2(A1), 
                   .I3(E), 
                   .O(D3));
   AND4B2 I_36_35 (.I0(A2), 
                   .I1(A0), 
                   .I2(A1), 
                   .I3(E), 
                   .O(D2));
   AND4B2 I_36_36 (.I0(A2), 
                   .I1(A1), 
                   .I2(A0), 
                   .I3(E), 
                   .O(D1));
   AND4B3 I_36_37 (.I0(A2), 
                   .I1(A1), 
                   .I2(A0), 
                   .I3(E), 
                   .O(D0));
endmodule
`timescale 1ns / 1ps

module regfile_8(clk, 
                 clr, 
                 raddr1, 
                 raddr0, 
                 waddr, 
                 wdata, 
                 wea, 
                 rdata0, 
                 rdata1);

    input clk;
    input clr;
    input [2:0] raddr1;
    input [2:0] raddr0;
    input [2:0] waddr;
    input [63:0] wdata;
    input wea;
   output [63:0] rdata0;
   output [63:0] rdata1;
   
   wire [63:0] XLXN_1;
   wire [63:0] XLXN_2;
   wire [63:0] XLXN_3;
   wire [63:0] XLXN_4;
   wire [63:0] XLXN_5;
   wire [63:0] XLXN_6;
   wire [63:0] XLXN_7;
   wire [63:0] XLXN_8;
   wire XLXN_22;
   wire XLXN_23;
   wire XLXN_24;
   wire XLXN_25;
   wire XLXN_26;
   wire XLXN_27;
   wire XLXN_29;
   wire XLXN_30;
   
   reg64 XLXI_1 (.ce(XLXN_22), 
                 .clk(clk), 
                 .clr(clr), 
                 .d(wdata[63:0]), 
                 .q(XLXN_1[63:0]));
   reg64 XLXI_2 (.ce(XLXN_23), 
                 .clk(clk), 
                 .clr(clr), 
                 .d(wdata[63:0]), 
                 .q(XLXN_2[63:0]));
   reg64 XLXI_3 (.ce(XLXN_24), 
                 .clk(clk), 
                 .clr(clr), 
                 .d(wdata[63:0]), 
                 .q(XLXN_3[63:0]));
   reg64 XLXI_4 (.ce(XLXN_25), 
                 .clk(clk), 
                 .clr(clr), 
                 .d(wdata[63:0]), 
                 .q(XLXN_4[63:0]));
   reg64 XLXI_5 (.ce(XLXN_26), 
                 .clk(clk), 
                 .clr(clr), 
                 .d(wdata[63:0]), 
                 .q(XLXN_5[63:0]));
   reg64 XLXI_6 (.ce(XLXN_27), 
                 .clk(clk), 
                 .clr(clr), 
                 .d(wdata[63:0]), 
                 .q(XLXN_6[63:0]));
   reg64 XLXI_7 (.ce(XLXN_29), 
                 .clk(clk), 
                 .clr(clr), 
                 .d(wdata[63:0]), 
                 .q(XLXN_7[63:0]));
   reg64 XLXI_8 (.ce(XLXN_30), 
                 .clk(clk), 
                 .clr(clr), 
                 .d(wdata[63:0]), 
                 .q(XLXN_8[63:0]));
   mux8to1_64bitwide XLXI_9 (.I0(XLXN_1[63:0]), 
                             .I1(XLXN_2[63:0]), 
                             .I2(XLXN_3[63:0]), 
                             .I3(XLXN_4[63:0]), 
                             .I4(XLXN_5[63:0]), 
                             .I5(XLXN_6[63:0]), 
                             .I6(XLXN_7[63:0]), 
                             .I7(XLXN_8[63:0]), 
                             .S0(raddr0[0]), 
                             .S1(raddr0[1]), 
                             .S2(raddr0[2]), 
                             .O(rdata0[63:0]));
   mux8to1_64bitwide XLXI_10 (.I0(XLXN_1[63:0]), 
                              .I1(XLXN_2[63:0]), 
                              .I2(XLXN_3[63:0]), 
                              .I3(XLXN_4[63:0]), 
                              .I4(XLXN_5[63:0]), 
                              .I5(XLXN_6[63:0]), 
                              .I6(XLXN_7[63:0]), 
                              .I7(XLXN_8[63:0]), 
                              .S0(raddr1[0]), 
                              .S1(raddr1[1]), 
                              .S2(raddr1[2]), 
                              .O(rdata1[63:0]));
   D3_8E_MXILINX_regfile_8 XLXI_11 (.A0(waddr[0]), 
                                    .A1(waddr[1]), 
                                    .A2(waddr[2]), 
                                    .E(wea), 
                                    .D0(XLXN_22), 
                                    .D1(XLXN_23), 
                                    .D2(XLXN_24), 
                                    .D3(XLXN_25), 
                                    .D4(XLXN_26), 
                                    .D5(XLXN_27), 
                                    .D6(XLXN_29), 
                                    .D7(XLXN_30));
   // synthesis attribute HU_SET of XLXI_11 is "XLXI_11_0"
endmodule
