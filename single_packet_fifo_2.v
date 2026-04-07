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
   input                             debug_dmem,
   input [7:0]                       debug_dmem_addr,
   output [31:0]                     debug_dmem_data_low,
   output [31:0]                     debug_dmem_data_mid,
   output [31:0]                     debug_dmem_data_high,
   output [7:0]                      debug_payload_start,
	input tpu_working,

    // --- Misc
	 output reg [2:0] 						 state,
	 input  										 freeze,
    input                               clk,
    input                               reset
  );

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
  wire [9:0]							  fifo_addr_in;
  
  assign tpu_port_b_out = ram_dout[DATA_WIDTH-1:0];
  
 // REG INTERFACE WILL BE EXPOSED PORTS
   reg [9:0] pkt_start_addr, pkt_end_addr;
	reg [9:0] start_payload_data;
  assign debug_payload_start = start_payload_data;
  
//  wire [31:0] active_offset = (port_master == 2'b10) ? gpu_addr : cpu_addr_in;
  wire [9:0] calculated_addr = else_addr_in_a + start_payload_data;
  wire [9:0] calculated_addr_b = else_addr_in_b + start_payload_data; 
  assign ram_addra = (port_master == 1'b0) ? fifo_addr_in : calculated_addr;
  //assign ram_addra  = port_master == 2'b10 ? (gpu_addr + start_payload_data) :port_master == 2'b01 ? (cpu_addr_in + start_payload_data) : fifo_addr_in;
  assign ram_dina   = port_master == 1'b1 ? else_data_in_a : {in_ctrl, in_data};
  assign ram_wea    = port_master == 2'b1 ? else_we_a   : (fifo_we);
 // TO BE CHECKED  assign ram_ena    = port_master == 2'b10 ? gpu_en :port_master == 2'b01 ? cpu_en                       : 1'b1;
  
  //assign ram_addrb  = port_master == 2'b00 ? fifo_addr_in: 8'b0;
  //assign ram_enb    = state == 3'b100 ? 1'b1  : 1'b0;
// Override Port B address and enable when in debug mode
// debug versions of the ram addrb/enb
  assign ram_addrb  = debug_dmem ? debug_dmem_addr : (port_master == 1'b0 ? fifo_addr_in : calculated_addr_b);
 assign ram_enb    = debug_dmem ? 1'b1 : ((state == 3'b100)||((state == 3'b011)&&tpu_working) ? 1'b1  : 1'b0); 
  
  // Non-debug versions of the ram addrb/enb
//   assign ram_addrb  = (port_master == 2'b00 ? fifo_addr_in : 8'b0);
//   assign ram_enb    = (state == 3'b100 ? 1'b1  : 1'b0);  

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
       .dinb(72'b0),
       .web(1'b0),         // Port B is read-only
       .enb(ram_enb),
       .doutb(ram_dout)
   );
	
/*	convertible_FIFO ram_inst (
       .addra(cpu_addr_in),    // Port A for writing
       .clka(clk),
       .dina(in_data),
       .wea(in_wr && fifo_we),
       .ena(ram_ena),
       .douta({out_ctrl, out_data}),

       .addrb(rd_ptr),    // Port B for reading
       .clkb(clk),
       .dinb(72'b0),
       .web(1'b0),         // Port B is read-only
       .enb(ram_enb),
		 .doutb(ram_dout)
   );*/
	
	
   parameter                     START = 3'b000;
   parameter                     CAPTURE_HEADER = 3'b001;
   parameter                     CAPTURE_PAYLOAD= 3'b010;
   parameter                     PROCESS = 3'b011;
   parameter                     FLUSH = 3'b100;

   // internal signals
   wire in_rdy_w;
   reg set_start_addr, set_end_addr;
   
   // --- NEW FLAGS ---
   reg set_payload_start;
   reg clear_payload_start;

   reg [7:0] head, tail;   //head points to read addr, tail points to next first empty addr where data will be written
   reg tail_wrapped;
	wire [7:0] tail_next, head_next;
   wire full, empty;
   reg read_req;

   assign tail_next = (tail == 8'hff) ? 0 : tail + 1;
   assign head_next = (head == 8'hff) ? 0 : head + 1;
   assign fifo_addr_in = (state == FLUSH) ? head : tail;

   assign empty = (head == tail) && !tail_wrapped;
   assign full = (head == tail) && tail_wrapped;

   assign in_rdy = (state == START) || (((state == CAPTURE_HEADER) || (state == CAPTURE_PAYLOAD)) && !set_end_addr);
	//assign in_rdy = in_rdy_w;
	assign out_wr = out_rdy && read_req && (~tpu_working);

 /* wire is_eop = (in_ctrl != 0);

  assign fifo_we = ((state == STATE_IDLE || state == STATE_RECEIVING) && in_wr);
  assign fifo_din = {in_ctrl, in_data};
*/
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
      if(out_wr) begin
      out_data   = ram_dout[DATA_WIDTH-1:0];
      out_ctrl   = ram_dout[DATA_WIDTH+CTRL_WIDTH-1:DATA_WIDTH];
		end
      case (state)
         START: begin
            if (in_wr && (in_ctrl != 0)) begin 
               state_next = CAPTURE_HEADER;
               fifo_we = 1;
               set_start_addr = 1;
               clear_payload_start = 1; // <--- FLAG REPLACES ASSIGNMENT
            end
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
            if (in_wr && (in_data[63:32] == 32'hC0DEFACE)) begin
               set_payload_start = 1;   // <--- FLAG REPLACES ASSIGNMENT
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
               // FIX 3: It is just a Ping/ARP. Pass it downstream immediately!
               state_next = FLUSH;
            end
         end
         FLUSH : begin
            if (head == pkt_end_addr) begin
               state_next = START;
               clear_payload_start = 1; // <--- FLAG REPLACES ASSIGNMENT
            end
         end
      endcase
   end
   
   always @(posedge clk) begin
      if (reset) begin
         head <= 0;
         tail <= 0;
         tail_wrapped <= 0;
         state <= START;
         pkt_start_addr <= 0;
         pkt_end_addr <= 0;
         read_req <= 0;
         start_payload_data <= 0; // <--- ADD SYNC RESET HERE
      end else begin
         state <= state_next;
         // --- NEW SYNCHRONOUS PAYLOAD LOGIC ---
         if (clear_payload_start) begin
            start_payload_data <= 0;
         end else if (set_payload_start) begin
            start_payload_data <= fifo_addr_in + 1; //  
         end

         // Set start addr reg
         if (set_start_addr) pkt_start_addr <= tail;

         // Set end addr reg
         if (set_end_addr || full) pkt_end_addr <= tail;

         // Increment tail pointer logic
         if (((state == START) && set_start_addr) || (((state == CAPTURE_HEADER) || (state == CAPTURE_PAYLOAD)) && !full) && in_wr) tail <= tail_next;

         // Increment head pointer logic
         if ((state == FLUSH) && (out_rdy && !empty)) head <= head_next;
         
         // tail wrapped logic
         if (tail == head_next) begin
            tail_wrapped <= 0;
         end else if (tail_next == head) begin
            tail_wrapped <= 1;
         end

         // Read out fifo logic, register the read request (basically if its in flush state) for one cycle to match 1 cycle latency of BRAM in order to match out_wr with when data is available
         read_req <= (state == FLUSH) && !empty;


         // TEST
         //pkts_ct <= pkts_ct_next;
         //first_data_reg <= (set_start_addr) ? in_data[31:0] : first_data_reg;
         //payload_cycles_reg <= ((state == CAPTURE_PAYLOAD) && (payload_cycles_reg != 32'hffffffff)) ? payload_cycles_reg + 1 : payload_cycles_reg;
         //out_wr_ct_reg <= (out_wr && (out_wr_ct_reg != 32'hffffffff)) ? out_wr_ct_reg + 1 : out_wr_ct_reg;
      end
   end



endmodule
