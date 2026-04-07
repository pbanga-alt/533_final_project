`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    16:31:27 03/23/2026 
// Design Name: 
// Module Name:    FIFO_test 
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
module FIFO_test   #(
      parameter DATA_WIDTH = 64,
      parameter CTRL_WIDTH = DATA_WIDTH/8,
      parameter UDP_REG_SRC_WIDTH = 2
   )
   (
      input  [DATA_WIDTH-1:0]             in_data,
      input  [CTRL_WIDTH-1:0]             in_ctrl,
      input                               in_wr,
      output                              in_rdy,

      output [DATA_WIDTH-1:0]             out_data,
      output [CTRL_WIDTH-1:0]             out_ctrl,
      output                              out_wr,
      input                               out_rdy,

      // CPU/GPU Interface
      input [7:0] cpu_addr_in,
      input [63:0] cpu_data_in,
      input cpu_we,
		input cpu_done_process,

      output reg cpu_start_process,
      output [7:0] pkt_start_addr_out,
      output [7:0] pkt_end_addr_out,
      output [63:0] cpu_data_out,
      
      // --- Register interface
      // input                               reg_req_in,
      // input                               reg_ack_in,
      // input                               reg_rd_wr_L_in,
      // input  [`UDP_REG_ADDR_WIDTH-1:0]    reg_addr_in,
      // input  [`CPCI_NF2_DATA_WIDTH-1:0]   reg_data_in,
      // input  [UDP_REG_SRC_WIDTH-1:0]      reg_src_in,

      // output                              reg_req_out,
      // output                              reg_ack_out,
      // output                              reg_rd_wr_L_out,
      // output  [`UDP_REG_ADDR_WIDTH-1:0]   reg_addr_out,
      // output  [`CPCI_NF2_DATA_WIDTH-1:0]  reg_data_out,
      // output  [UDP_REG_SRC_WIDTH-1:0]     reg_src_out,

      // misc
      input                                reset,
      input                                clk
   );

 parameter                     START = 3'b000;
   parameter                     CAPTURE_HEADER = 3'b001;
   parameter                     CAPTURE_PAYLOAD= 3'b010;
   parameter                     PROCESS = 3'b011;
   parameter                     FLUSH = 3'b100;

   // internal signals
   reg [2:0] state, state_next;

   reg set_start_addr, set_end_addr;

   reg [7:0] head, tail;   //head points to read addr, tail points to next first empty addr where data will be written
   reg tail_wrapped;
	wire [7:0] tail_next, head_next;
   wire full, empty;
   reg fifo_we;
   wire [7:0] fifo_addr_in;
   reg read_req;

   assign tail_next = (tail == 8'hff) ? 0 : tail + 1;
   assign head_next = (head == 8'hff) ? 0 : head + 1;
   assign fifo_addr_in = (state == FLUSH) ? head : tail;

   assign empty = (head == tail) && !tail_wrapped;
   assign full = (head == tail) && tail_wrapped;

   // REG INTERFACE WILL BE EXPOSED PORTS
   reg [7:0] pkt_start_addr, pkt_end_addr;
   // wire cpu_done_process;
   // wire [7:0] cpu_addr_in;
   // wire cpu_we;
   // reg [63:0] cpu_data_in;
	// wire [63:0] cpu_data_out;
   // reg [7:0] cpu_ctrl_in;
	// wire [7:0] cpu_ctrl_out;

   assign pkt_start_addr_out = pkt_start_addr;
   assign pkt_end_addr_out = pkt_end_addr_out;

   assign in_rdy = (state == START) || (((state == CAPTURE_HEADER) || (state == CAPTURE_PAYLOAD)) && !set_end_addr);
	assign out_wr = out_rdy && read_req;
	
   // FOR TESTING
   // wire [31:0] mem_addr, command_reg;
   // wire [31:0] mem_data_lsb, mem_data_msb, mem_ctrl;
   // wire [31:0] pkt_start_debug, pkt_end_debug;
   // wire [31:0] flag;
   // wire [31:0] first_data_debug;
   // wire [31:0] head_ptr_debug, tail_ptr_debug;
   // wire [31:0] payload_cycles_debug;
   // wire [31:0] curr_state_debug;
   // wire [31:0] out_wr_ct_debug;

   // assign mem_data_lsb = cpu_data_out[31:0];
   // assign mem_data_msb = cpu_data_out[63:32];
   // assign mem_ctrl = {{28'd0}, cpu_ctrl_out};
   // assign pkt_start_debug = pkt_start_addr;
   // assign pkt_end_debug = pkt_end_addr;
   // reg [31:0] pkts_ct, pkts_ct_next;
   // assign flag = pkts_ct;
   // reg [31:0] first_data_reg;
   // assign first_data_debug = first_data_reg;
   // assign head_ptr_debug = {{24'd0}, head};
   // assign tail_ptr_debug = {{24'd0}, tail};
   // reg [31:0] payload_cycles_reg;
   // assign payload_cycles_debug = payload_cycles_reg;
   // assign curr_state_debug = {{29'd0}, state};
   // reg [31:0] out_wr_ct_reg;
   // assign out_wr_ct_debug = out_wr_ct_reg;

	// assign state_out = state;
	// assign start_addr_out = pkt_start_addr;
	// assign end_addr_out = pkt_end_addr;
   // assign cpu_done_process = 1;
   // assign cpu_addr_in = (command_reg[2:0] == 3'b001) ? mem_addr : 8'hff;
   // assign cpu_we = 0;

   
   // -----------------------------------------vSTART LOGIC ------------------------------------------------------------
   fifo_data_bram fifo_data_bram_i (
      .addra(fifo_addr_in),   // FOR FIFO OP
      .addrb(cpu_addr_in),    // DMEM ACCESS FROM CPU
      .clka (clk),
      .clkb (clk),
      .dina(in_data),
      .dinb(cpu_data_in),
      .douta(out_data),
      .doutb(cpu_data_out),
      .wea(in_wr && fifo_we),
      .web(cpu_we)
   );

   fifo_ctrl_bram fifo_ctrl_bram_i (
      .addra(fifo_addr_in),   // FOR FIFO OP
      .clka (clk),
      .dina(in_ctrl),
      .douta(out_ctrl),
      .wea(in_wr && fifo_we)
   );
   

   // State machine / controller
   always @(*) begin
      state_next = state;
      fifo_we = 0;
      set_start_addr = 0;
      set_end_addr = 0;
      cpu_start_process = 0;

      //test
      // pkts_ct_next = pkts_ct;
      // cpu_data_in = 0;
      // cpu_ctrl_in = 0;

      case (state)
         START: begin
            if (in_wr && (in_ctrl != 0)) begin
               state_next = CAPTURE_HEADER;
               fifo_we = 1;
               set_start_addr = 1;
               //pkts_ct_next = pkts_ct + 1; // TEST
            end
         end
         CAPTURE_HEADER: begin
            if (in_wr && (in_ctrl == 0)) begin
               state_next = CAPTURE_PAYLOAD;
               set_end_addr = 1;
            end
            if (!full) begin
               fifo_we = 1;
            end
         end
         CAPTURE_PAYLOAD: begin
            if (in_wr && (in_ctrl != 0)) begin
               state_next = PROCESS;
               set_end_addr = 1;
            end
            if (!full) begin
               fifo_we = 1;
            end
         end
         PROCESS : begin
            if (cpu_done_process) begin
               state_next = FLUSH;
            end
            cpu_start_process = 1'b1;
            //cpu_data_in = cpu_data_out + 5;
            //cpu_ctrl_in = cpu_ctrl_out;
         end
         FLUSH : begin
            if (head == pkt_end_addr) begin
               state_next = START;
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

         // TEST
         //pkts_ct <= 0;
         //payload_cycles_reg <= 0;
         //out_wr_ct_reg <= 0;

      end else begin
         state <= state_next;

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
