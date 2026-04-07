`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    15:52:35 03/28/2026 
// Design Name: 
// Module Name:    fifo_processor_tb 
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
module fifo_processor_tb;


  // --- Parameters ---
  localparam DATA_WIDTH       = 64;
  localparam CTRL_WIDTH       = 8;
  localparam FIFO_DEPTH_WORDS = 256;
  localparam UDP_REG_SRC_WIDTH = 2;
  localparam CLK_PERIOD       = 20; 
  
  integer i;

  // --- Inputs to UUT ---
  reg                         clk;
  reg                         reset;
  
  // Data path inputs
  reg  [DATA_WIDTH-1:0]       in_data;
  reg  [CTRL_WIDTH-1:0]       in_ctrl;
  reg                         in_wr;
  reg                         out_rdy;

  // Legacy / Direct Debug Ports
 
  // --- Outputs from UUT ---
  wire [DATA_WIDTH-1:0]       out_data;
  wire [CTRL_WIDTH-1:0]       out_ctrl;
  wire                        out_wr;
  wire                        in_rdy;
  
//  wire [31:0]                 debug_instr_out;
 // wire [8:0]                  PC_END;

  // --- Testbench internal variables ---
  integer sent_word_count;

  // --- Instantiate the Unit Under Test (UUT) ---
  wrap #(
    .DATA_WIDTH(DATA_WIDTH),
    .CTRL_WIDTH(CTRL_WIDTH),
    .FIFO_DEPTH_WORDS(FIFO_DEPTH_WORDS),
    .UDP_REG_SRC_WIDTH(UDP_REG_SRC_WIDTH)
  ) uut (
    .out_data(out_data),
    .out_ctrl(out_ctrl),
    .out_wr(out_wr),
    .out_rdy(out_rdy),
    .in_data(in_data),
    .in_ctrl(in_ctrl),
    .in_wr(in_wr),
    .in_rdy(in_rdy),
  //  .debug_pc(debug_pc),
  //  .debug_enable(debug_enable),
  //  .debug_instr_in(debug_instr_in),
  //  .debug_instr_write_en(debug_instr_write_en),
  //  .debug_instr_out(debug_instr_out),
  //  .PC_END(PC_END),
    .clk(clk),
    .reset(reset)
    
    // 32-bit Software Registers
  );

  // --- Clock generator ---
  always #(CLK_PERIOD/2) clk = ~clk;

  // --- Helper Tasks ---

  task send_word;
    input [CTRL_WIDTH-1:0] ctrl;
    input [DATA_WIDTH-1:0] data;
    begin
      wait(in_rdy);
      @(posedge clk);
      in_data <= data;
      in_ctrl <= ctrl;
      in_wr   <= 1'b1;
      sent_word_count = sent_word_count + 1;
      @(posedge clk);
      in_wr   <= 1'b0;
      in_data <= 64'bx;
      in_ctrl <= 8'bx;
    end
  endtask

  // --- Main Test Sequence ---
  initial begin
    // 1. Initialize Inputs
    clk = 1'b0;
    reset = 1'b1;
    in_data = 64'bx;
    in_ctrl = 8'bx;
    in_wr = 1'b0;
    out_rdy = 1'b0; 
    
  
    sent_word_count = 0;

    #30;
    reset = 1'b0; 
    #40;

    $display("--- Starting Pipeline Setup ---");

    // 2. Freeze Pipeline & Assert SW Reset
  //  sw_reset           = 32'd1; // Assert reset
  //  cpu_imem_interact  = 32'd1; // Freeze CPU 
  //  gpu_imem_interact  = 32'd1; // Freeze GPU 
  //  fifo_dmem_interact = 32'd1; // Freeze FIFO
 //   #500;

   
   

    // 5. Send Network Packet Data
    $display("--- Sending MATH DATA (UDP) Packet ---");
    send_word(8'hFF, 64'h008000080006003C); 
    send_word(8'h00, 64'h004E46324303A036); 
    send_word(8'h00, 64'h9F0A0EB008060001); 
    send_word(8'h00, 64'h080006040001A036); 
    send_word(8'h00, 64'h9F0A0EB00A000F03); 
    send_word(8'h00, 64'h0000000000000A00); 
    send_word(8'h00, 64'h0F02000000000000); 
    send_word(8'h00, 64'h0000000000000000); 
    send_word(8'h10, 64'h0000000000B91D68); // End of Packet

    #300;
    out_rdy <= 1'b1;
    #300; 
    out_rdy <= 1'b0;

    $display("--- Sending TRIGGER/bfloat16 Packet ---");
    send_word(8'hFF, 64'h0001001100060088);
    send_word(8'h00, 64'hA0369F0A5F4B004E);
    send_word(8'h00, 64'h4632430008004500);
    send_word(8'h00, 64'h007A168F40003F11);
    send_word(8'h00, 64'hF5DE0A000F030A00);
    send_word(8'h00, 64'h0C03B88B138A0066);
    send_word(8'h00, 64'h42E2AAAAAAAAAAAA);
    send_word(8'h00, 64'hC0DEFACE0000000F); // TRIGGER
    send_word(8'h00, 64'h3E9E3ED73F193EE1);
    send_word(8'h00, 64'h3EA83F61BEE63F38);
	 send_word(8'h00, 64'hBF453EAE3F21BE38);
	 send_word(8'h00, 64'h3EFABF19BE613F0C);
	 send_word(8'h00, 64'hBE193E8A3F4F3ECC);
    send_word(8'h00, 64'h3E993D4CBE4C3DCC);
    send_word(8'h00, 64'h0000000000003F68);
	 send_word(8'h00, 64'h000000000000BF07);
	 send_word(8'h00, 64'h000000000000BE8A);
	 send_word(8'h00, 64'h0000000000003F28);
    send_word(8'h00, 64'h000000000000BDF5); // bfloat16
    send_word(8'h00, 64'h0000000000000000); // bfloat16
    send_word(8'h00, 64'h0000000000000000);
    send_word(8'h01, 64'h0000000000000000); // End of Packet

    #25;
    out_rdy <= 1'b1;

    #12000; // Allow sufficient processing time
    $display("Simulation Complete.");
    $stop;
  end

endmodule
