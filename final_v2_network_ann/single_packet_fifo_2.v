`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    14:26:42 03/28/2026 
// Design Name: 
// Module Name:    single_packet_fifo_2 
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
module single_packet_fifo_2
   #(parameter DATA_WIDTH = 64,
    parameter CTRL_WIDTH = 8,
    parameter UDP_REG_SRC_WIDTH = 2,
    parameter FIFO_DEPTH_WORDS = 256 // 256 * 8 bytes = 2KB buffer
  )
  (
    input  						    port_master,
    // --- Data path interface (output)
    output reg [DATA_WIDTH-1:0]         out_data,
    output reg [CTRL_WIDTH-1:0]         out_ctrl,
    output                              out_wr,
    input                               out_rdy,

    // --- Data path interface (input)
    input      [DATA_WIDTH-1:0]         in_data,
    input      [CTRL_WIDTH-1:0]         in_ctrl,
    input                               in_wr,
    output                              in_rdy,

input [31:0] mem_addr_debug,
input [63:0] tpu_din,
input [9:0] tpu_mem_write_addr,
input tpu_wen,
	output reg cpu_start_process,
    // CPU Data Memory interface

	input 		[9:0]					else_addr_in_a,
	input       [9:0]					else_addr_in_b,
   input		[DATA_WIDTH-1:0]		else_data_in_a,
	output [DATA_WIDTH-1:0] tpu_port_b_out,
	input		[CTRL_WIDTH-1:0]		cpu_in_ctrl,
	input 								else_we_a,

	output 		[DATA_WIDTH-1:0]		CG_out_data,
	output		[CTRL_WIDTH-1:0]		CG_out_ctrl,
	input								cpu_en,
	
	    // CPU Data Memory interface

	//pbanga - input 	[7:0]						gpu_addr,
   //pbanga - input		[DATA_WIDTH-1:0]		gpu_in_data,
	input		[CTRL_WIDTH-1:0]		gpu_in_ctrl,
	//pbanga - input 								gpu_we,

	input									gpu_en,

    // DMEM debug
    input                               debug_dmem,
    input [9:0]                       debug_dmem_addr,
    output [31:0]                     debug_dmem_data_low,
    output [31:0]                     debug_dmem_data_mid,
    output [31:0]                     debug_dmem_data_high,
    output [9:0]                      debug_payload_start,
    
    // --- NEW: Inference Result Pointer ---
    output reg [9:0]                  result_addr,
    
    output [31:0]                     fifo_status,
	input                             tpu_working,

    // --- Misc
	output reg [2:0] 						 state,
	input  										 freeze,
    input                               clk,
    input                               reset,
 input [9:0] tpu_input_addr_in,
 output [63:0] tpu_input_mem_out 
  );
   // local parameter
   parameter                     START = 3'b000;
   parameter                     CAPTURE_HEADER = 3'b001;
   parameter                     CAPTURE_PAYLOAD= 3'b010;
   parameter                     PROCESS = 3'b011;
   parameter                     FLUSH = 3'b100;
  localparam ADDR_WIDTH = 8;
/*
  // States for the Finite State Machine
  localparam STATE_IDLE      = 2'b00; // Empty and ready to receive
  localparam STATE_RECEIVING = 2'b01; // Actively receiving a packet
  localparam STATE_FULL      = 2'b10; // Packet stored, waiting for output to be ready
  localparam STATE_SENDING   = 2'b11; // Actively sending the packet*/

  reg [2:0] state_next;

  // Head (rd_ptr) and Tail (wr_ptr) pointers
  reg [ADDR_WIDTH-1:0] wr_ptr, rd_ptr;
  reg [ADDR_WIDTH:0]   pkt_len_words; // Stores the length of the buffered packet in words

  wire [DATA_WIDTH+CTRL_WIDTH-1:0] fifo_din;
  wire [DATA_WIDTH+CTRL_WIDTH-1:0] fifo_dout;
  reg                              fifo_we;
  
  // Wires for BRAM interface
  wire [DATA_WIDTH+CTRL_WIDTH-1:0] ram_dina;
  wire [DATA_WIDTH+CTRL_WIDTH-1:0] ram_douta;
  wire                             ram_wea;
  wire [9:0]                       ram_addra;
  wire                             ram_ena;
  
  wire [DATA_WIDTH+CTRL_WIDTH-1:0] ram_dout;
  wire [9:0]                       ram_addrb;
  wire                             ram_enb;
  wire [9:0]					   fifo_addr_in;
   reg set_result_addr;
   reg [9:0] next_result_addr;
  
  assign tpu_port_b_out = ram_dout[DATA_WIDTH-1:0];
  
  // REG INTERFACE WILL BE EXPOSED PORTS
  reg [9:0] pkt_start_addr, pkt_end_addr;
  reg [9:0] start_payload_data;
  assign debug_payload_start = start_payload_data;
   wire full, empty;
  
//  wire [31:0] active_offset = (port_master == 2'b10) ? gpu_addr : cpu_addr_in;
  wire [9:0] calculated_addr = else_addr_in_a + start_payload_data;
  wire [9:0] calculated_addr_b = tpu_wen ? result_addr : else_addr_in_b + start_payload_data;
  
  assign ram_addra = (port_master == 1'b0) ? fifo_addr_in : calculated_addr;
  //assign ram_addra  = port_master == 2'b10 ? (gpu_addr + start_payload_data) :port_master == 2'b01 ? (cpu_addr_in + start_payload_data) : fifo_addr_in;
  assign ram_dina   = port_master == 1'b1 ? else_data_in_a : {in_ctrl, in_data};
  assign ram_wea    = port_master == 1'b1 ? else_we_a   : (fifo_we);

  assign ram_addrb  = debug_dmem ? debug_dmem_addr : (port_master == 1'b0 ? fifo_addr_in : calculated_addr_b);
 assign ram_enb    = debug_dmem ? 1'b1 : (((state == FLUSH) && out_rdy && !empty) || ((state == PROCESS) && tpu_working) ? 1'b1  : 1'b0);

  // Wire the BRAM output to the debug port (64-bit data + 8-bit control)
  assign debug_dmem_data_low  = ram_dout[31:0];               // Data [31:0]
  assign debug_dmem_data_mid  = ram_dout[63:32];              // Data [63:32]
  assign debug_dmem_data_high = {24'b0, ram_dout[71:64]};     // Control [7:0] padded to 32 bits

   convertible_FIFO ram_inst (
       .addra(ram_addra),    // Port A for writing
       .clka(clk),
       .dina(ram_dina),
       .wea(ram_wea),
       .ena(1'b1),
       .douta({CG_out_ctrl, CG_out_data}),

       .addrb(ram_addrb),    // Port B for reading
       .clkb(clk),
       .dinb({8'b00000001,tpu_din}),
       .web(tpu_wen),  
       .enb(ram_enb),
       .doutb(ram_dout)
   );
   
   // --- New 64-bit ANN BRAM Signals ---
   reg [7:0]  bram_ann_addr;       
   reg        bram_ann_we;         
   reg [63:0] bram_ann_data;       
   reg        stop_ann_capture;
   reg        ann_payload_flag;
   reg        ann_payload_flag_next;
   wire [63:0] ann_doutb;

wire [7:0] addr_decision = debug_dmem ? mem_addr_debug[7:0] :  tpu_input_addr_in[7:0] ;
   // --- 64-bit / 256-deep ANN Activation BRAM ---
   Ann_activation_mem ann_bram_i(
      .addra (bram_ann_addr),      
      .addrb (addr_decision),               // Placeholder: Map to TPU/CPU logic when ready
      .clka  (clk),
      .clkb  (clk),
      .dina  (bram_ann_data),      
      .dinb  (64'd0),              
      .douta (),                   
      .doutb (tpu_input_mem_out),          
      .ena   (1'b1),               
      .enb   (1'b1),               
      .wea   (bram_ann_we),        
      .web   (1'b0)                 
   );
	

   // internal signals
   wire in_rdy_w;
   reg set_start_addr, set_end_addr;
   
   // --- NEW FLAGS ---
   reg set_payload_start;
   reg clear_payload_start;

   reg [9:0] head, tail;   //head points to read addr, tail points to next first empty addr where data will be written
   reg tail_wrapped;
   wire [9:0] tail_next, head_next;
   reg read_req;

   assign tail_next = (tail == 8'hff) ? 0 : tail + 1;
   assign head_next = (head == 8'hff) ? 0 : head + 1;
   assign fifo_addr_in = (state == FLUSH) ? head : tail;

   assign empty = (head == tail) && !tail_wrapped;
   assign full = (head == tail) && tail_wrapped;

									   
   assign in_rdy = ((state == START) || (((state == CAPTURE_HEADER) || (state == CAPTURE_PAYLOAD)) && !set_end_addr)) && !out_wr;
   assign out_wr = out_rdy && read_req && (~tpu_working);

  // State machine / controller
  always @(*) begin
      state_next = state;
      fifo_we = 0;
      set_start_addr = 0;
      set_end_addr = 0;
      cpu_start_process = 0;
      
      // Initialize new flags to 0
      set_payload_start = 0;
      clear_payload_start = 0;
      set_result_addr = 0;
      next_result_addr = 0;
      
      ann_payload_flag_next = ann_payload_flag; // Maintain state by default

      out_data   = ram_dout[DATA_WIDTH-1:0];
      out_ctrl   = ram_dout[DATA_WIDTH+CTRL_WIDTH-1:DATA_WIDTH];
      case (state)
         START: begin
            if (in_wr && (in_ctrl != 0)) begin 
               state_next = CAPTURE_HEADER;
               fifo_we = 1;
               set_start_addr = 1;
               clear_payload_start = 1; // <--- FLAG REPLACES ASSIGNMENT
            end
            ann_payload_flag_next = 0; // Reset ANN Flag
         end
         CAPTURE_HEADER: begin
            if (in_wr && (in_ctrl == 0)) begin
               state_next = CAPTURE_PAYLOAD;
               set_end_addr = 1;
            end
            
            // FIX 1: Only write when valid data is present
            if (!full && in_wr) begin
               fifo_we = 1;
            end
         end
         CAPTURE_PAYLOAD: begin
            // --- NEW: Detect exact final packet marker to ungate CPU ---
            if (in_wr && (in_data == 64'hC0DEFACE00000000)) begin
               set_payload_start = 1;
            end
            
            // Trigger ANN extraction on any valid packet header
            if (in_wr && (in_data[63:32] == 32'hC0DEFACE)) begin
               ann_payload_flag_next = 1; 
            end
            
            // --- NEW: Detect DEADBEEF trailer to locate result injection point ---
            if (in_wr && (in_data == 64'hDEADBEEF00000000)) begin
               set_result_addr = 1;
               next_result_addr = tail + 1; // The all-zeros block sits exactly at tail+1
            end
            
            if (in_wr && (in_ctrl != 0)) begin
               state_next = PROCESS;
               set_end_addr = 1; // -> captures the end address as the current tail address
            end            
            // FIX 1: Only write when valid data is present
            if (!full && in_wr) begin
               fifo_we = 1;
            end
         end
         PROCESS : begin
            if (start_payload_data) begin
               // Payload found! Wake up the CPU.
               cpu_start_process = 1'b1;
               
               // Wait for CPU to finish before flushing
               if (freeze) state_next = FLUSH;
               
            end else begin
               state_next = FLUSH; // Silently buffer standard packets
            end
         end
         FLUSH : begin
            if (head == pkt_end_addr) begin
               state_next = START;
               clear_payload_start = 1; 
            end
         end
      endcase
   end
reg [11:0] addr_counter;
   
   always @(posedge clk) begin
      if (reset) begin
   	     addr_counter <= 0;
         head <= 0;
         tail <= 0;
         tail_wrapped <= 0;
         state <= START;
         pkt_start_addr <= 0;
         pkt_end_addr <= 0;
         read_req <= 0;
         
         start_payload_data <= 0; 
         result_addr <= 0;
         
         // ANN Reset State
         bram_ann_addr <= 8'hFF; 
         bram_ann_we <= 0;
         bram_ann_data <= 0;
         stop_ann_capture <= 0;
         ann_payload_flag <= 0;
         
      end else begin
         state <= state_next;
         if(addr_counter < 2000 && state > 3'd0) addr_counter <= addr_counter + 1; 
         
         ann_payload_flag <= ann_payload_flag_next;
         bram_ann_we <= 0;
         
         // Synchronous clear/set logic for CPU Triggers
         if (clear_payload_start) begin
            start_payload_data <= 0;
         end else if (set_payload_start) begin
            start_payload_data <= fifo_addr_in + 1;
         end
         
         // Capture the precise write-back location from DEADBEEF
         if (set_result_addr) begin
            result_addr <= next_result_addr;
         end
         
         // --- ANN Logic Triggers ---
         if (state == START) begin
            stop_ann_capture <= 0;
         end
         
         if ((state == CAPTURE_PAYLOAD) && in_wr) begin
            // Initialization Marker (Triggers only on the first packet of a file)
            if (in_data[63:32] == 32'hCAFEBABE) begin
               bram_ann_addr <= 8'hFF;  
            end
            // Stop Marker
            if (in_data[63:32] == 32'hFACEC0DE) begin
               stop_ann_capture <= 1'b1;
            end
         end
         
         // --- Direct 1-to-1 Capture Logic for ANN Phase ---
         if ((state == CAPTURE_PAYLOAD) && in_wr && ann_payload_flag && !stop_ann_capture && 
             (in_data[63:32] != 32'hFACEC0DE) && 
             (in_data[63:32] != 32'hC0DEFACE) && 
             (in_data[63:32] != 32'hCAFEBABE)) begin
            
            bram_ann_data <= in_data; 
            bram_ann_we <= 1'b1;
            bram_ann_addr <= bram_ann_addr + 1'b1;
         end

         // Set start addr reg
         if (set_start_addr) pkt_start_addr <= tail;

         // Set end addr reg
         if (set_end_addr || full) pkt_end_addr <= tail;

         // Increment tail pointer logic
         if (((state == START) && set_start_addr) || (((state == CAPTURE_HEADER) || (state == CAPTURE_PAYLOAD)) && !full) && in_wr) tail <= tail_next;

         // Increment head pointer logic
         if ((state == FLUSH) && ram_enb) head <= head_next;
         // tail wrapped logic
         if (tail == head_next) begin
            tail_wrapped <= 0;
         end else if (tail_next == head) begin
            tail_wrapped <= 1;
         end

         if (out_rdy) begin
             read_req <= (state == FLUSH) && !empty;
         end
      end
   end

//   wire [11:0] to_la_addr = debug_dmem ? mem_addr_debug[11:0] : addr_counter;
 //  wire to_la_wea = debug_dmem ? 1'b0 : 1'b1;
   
   instruction_memory np_state_la (
		.clka(clk), 
		.clkb(clk), 
		.dina({16'b0,3'b0,port_master,3'b0,freeze,2'b0,start_payload_data,cpu_start_process,1'b0,state}),    
		.dinb(32'd0),
		.addra(addr_counter),
		.addrb(mem_addr_debug[11:0]),        	      
		.wea(1'b1),
		.web(1'b0),      	      
		.douta(),         	      
		.doutb(fifo_status)         	      
	);


endmodule
