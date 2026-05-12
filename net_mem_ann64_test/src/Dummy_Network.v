`timescale 1ns/1ps

module network_mem 
   #(
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
      
      // --- Coprocessor Handshake
      output reg                          cpu_start_process,
      //input                               freeze,
      
      // --- Register interface
      input                               reg_req_in,
      input                               reg_ack_in,
      input                               reg_rd_wr_L_in,
      input  [`UDP_REG_ADDR_WIDTH-1:0]    reg_addr_in,
      input  [`CPCI_NF2_DATA_WIDTH-1:0]   reg_data_in,
      input  [UDP_REG_SRC_WIDTH-1:0]      reg_src_in,

      output                              reg_req_out,
      output                              reg_ack_out,
      output                              reg_rd_wr_L_out,
      output [`UDP_REG_ADDR_WIDTH-1:0]    reg_addr_out,
      output [`CPCI_NF2_DATA_WIDTH-1:0]   reg_data_out,
      output [UDP_REG_SRC_WIDTH-1:0]      reg_src_out,

      // misc
      input                               reset,
      input                               clk
   );

   // local parameter
   parameter                     START = 3'b000;
   parameter                     CAPTURE_HEADER = 3'b001;
   parameter                     CAPTURE_PAYLOAD= 3'b010;
   parameter                     PROCESS = 3'b011;
   parameter                     FLUSH = 3'b100;

   // internal signals
   reg [2:0] state, state_next;

   reg set_start_addr, set_end_addr;

   reg [9:0] head, tail;   
   reg tail_wrapped;
   wire [9:0] tail_next, head_next;
   wire full, empty;
   reg fifo_we;
   wire [9:0] fifo_addr_in;
   reg read_req;

   assign tail_next = (tail == 10'h3ff) ? 0 : tail + 1;
   assign head_next = (head == 10'h3ff) ? 0 : head + 1;
   assign fifo_addr_in = (state == FLUSH) ? head : tail;

   assign empty = (head == tail) && !tail_wrapped;
   assign full = (head == tail) && tail_wrapped;

   // REG INTERFACE WILL BE EXPOSED PORTS
   reg [9:0] pkt_start_addr, pkt_end_addr;
   wire [9:0] cpu_addr_in;
   reg cpu_we;
   reg freeze;
   reg [63:0] cpu_data_in;
   wire [63:0] cpu_data_out;
   reg [9:0] cpu_ctrl_in;
   wire [9:0] cpu_ctrl_out;

   assign in_rdy = (state == START) || (((state == CAPTURE_HEADER) || (state == CAPTURE_PAYLOAD)) && !set_end_addr);
   assign out_wr = out_rdy && read_req;
   
   // FOR TESTING
   wire [31:0] mem_addr, command_reg;
   wire [31:0] mem_data_lsb, mem_data_msb, mem_ctrl;
   wire [31:0] pkt_start_debug, pkt_end_debug;
   wire [31:0] flag;
   wire [31:0] first_data_debug;
   wire [31:0] head_ptr_debug, tail_ptr_debug;
   wire [31:0] payload_cycles_debug;
   wire [31:0] curr_state_debug;
   wire [31:0] out_wr_ct_debug;
   
   // --- BRAM CPU Extraction Wires ---
   wire [31:0] mem_ann_addr;       
   wire [31:0] mem_ann_data_0;     
   wire [31:0] mem_ann_data_1;     
   wire [63:0] ann_doutb;          

   assign mem_ann_data_0 = ann_doutb[31:0];
   assign mem_ann_data_1 = ann_doutb[63:32];

   assign mem_data_lsb = cpu_data_out[31:0];
   assign mem_data_msb = cpu_data_out[63:32];
   assign mem_ctrl = {{28'd0}, cpu_ctrl_out};
   assign pkt_start_debug = pkt_start_addr;
   assign pkt_end_debug = pkt_end_addr;
   reg [31:0] pkts_ct, pkts_ct_next;
   assign flag = pkts_ct;
   reg [31:0] first_data_reg;
   assign first_data_debug = first_data_reg;
   assign head_ptr_debug = {{24'd0}, head};
   assign tail_ptr_debug = {{24'd0}, tail};
   reg [31:0] payload_cycles_reg;
   assign payload_cycles_debug = payload_cycles_reg;
   assign curr_state_debug = {{29'd0}, state};
   reg [31:0] out_wr_ct_reg;
   assign out_wr_ct_debug = out_wr_ct_reg;

   // --- RESULT ADDR LOGIC ---
   reg [9:0] result_addr;
   reg set_result_addr;
   reg [9:0] next_result_addr;
   
   reg set_payload_start;
   reg clear_payload_start;
   reg [9:0] start_payload_data; // Non-zero indicates final packet

   // Dynamically route CPU Address based on State
   // If software register triggers a read, use mem_addr. Otherwise, target result_addr directly.
   assign cpu_addr_in = (command_reg[2:0] == 3'b001) ? mem_addr : result_addr;
   
   // --- New 64-bit ANN BRAM Signals ---
   reg [7:0]  bram_ann_addr;       
   reg        bram_ann_we;         
   reg [63:0] bram_ann_data;       
   reg        stop_ann_capture;
   reg        ann_payload_flag;
   reg        ann_payload_flag_next;

   
   // ----------------------------------------- BRAM LOGIC ------------------------------------------------------------
   FIFO_bram FIFO_bram_i (
      .addra(fifo_addr_in),   
      .addrb(cpu_addr_in),    
      .clka (clk),
      .clkb (clk),
      .dina({in_ctrl, in_data}),
      .dinb({cpu_ctrl_in, cpu_data_in}),
      .douta({out_ctrl, out_data}),
      .doutb({cpu_ctrl_out, cpu_data_out}),
      .ena(1'b1),
      .wea(fifo_we),    
      .web(cpu_we)
   );
   
   Ann_activation_mem ann_bram_i(
      .addra (bram_ann_addr),      
      .addrb (mem_ann_addr[7:0]),  
      .clka  (clk),
      .clkb  (clk),
      .dina  (bram_ann_data),      
      .dinb  (64'd0),              
      .douta (),                   
      .doutb (ann_doutb),          
      .ena   (1'b1),                
      .enb   (1'b1),                
      .wea   (bram_ann_we),        
      .web   (1'b0)                 
   );

   
   // State machine / controller
   always @(*) begin
      state_next = state;
      fifo_we = 0;
      set_start_addr = 0;
      set_end_addr = 0;
	  freeze = 0;
      cpu_data_in = 0;
      cpu_ctrl_in = 0;
      cpu_we = 0;
      cpu_start_process = 0;
      
      set_result_addr = 0;
      next_result_addr = 0;
      set_payload_start = 0;
      clear_payload_start = 0;
      
      ann_payload_flag_next = ann_payload_flag;

      pkts_ct_next = pkts_ct;

      case (state)
         START: begin
            if (in_wr && (in_ctrl != 0)) begin
               state_next = CAPTURE_HEADER;
               fifo_we = 1;
               set_start_addr = 1;
               clear_payload_start = 1;
               pkts_ct_next = pkts_ct + 1;
            end
            ann_payload_flag_next = 0;
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
            // --- NEW: Detect exact final packet marker to ungate CPU ---
            if (in_wr && (in_data == 64'hC0DEFACE00000000)) begin
               set_payload_start = 1;
            end
            
            // Trigger ANN extraction on any valid packet header
            if (in_wr && (in_data[63:32] == 32'hC0DEFACE)) begin
               ann_payload_flag_next = 1; 
            end
            
            if (in_wr && (in_data == 64'hDEADBEEF00000000)) begin
               set_result_addr = 1;
               next_result_addr = tail + 1; // The all-zeros block sits exactly at tail+1
            end
            
            if (in_wr && (in_ctrl != 0)) begin
               state_next = PROCESS;
               set_end_addr = 1; 
            end            
            if (!full && in_wr) begin
               fifo_we = 1;
            end
         end
         PROCESS : begin
            // CPU only fires if start_payload_data is non-zero (occurs strictly on the final packet)
            if (start_payload_data != 0) begin
               cpu_start_process = 1'b1;
               
               // Drop the semaphore exactly at the result address
               cpu_data_in = 64'd1;
               cpu_we = 1'b1;
               freeze = 1'b1;
               if (freeze) state_next = FLUSH;
            end else begin
               state_next = FLUSH; // Silently buffer standard packets
            end
            cpu_ctrl_in = cpu_ctrl_out;
         end
         FLUSH : begin
            if (head == pkt_end_addr) begin
               state_next = START;
               clear_payload_start = 1;
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

         pkts_ct <= 0;
         payload_cycles_reg <= 0;
         out_wr_ct_reg <= 0;
         
         bram_ann_addr <= 8'hFF; 
         bram_ann_we <= 0;
         bram_ann_data <= 0;
         stop_ann_capture <= 0;
         ann_payload_flag <= 0;
         
         result_addr <= 0;
         start_payload_data <= 0;

      end else begin
         state <= state_next;
         bram_ann_we <= 0;
         ann_payload_flag <= ann_payload_flag_next;
         
         if (clear_payload_start) begin
            start_payload_data <= 0;
         end else if (set_payload_start) begin
            start_payload_data <= fifo_addr_in + 1; 
         end
         
         if (set_result_addr) result_addr <= next_result_addr;
         
         if (state == START) begin
            stop_ann_capture <= 0;
         end
         
         if ((state == CAPTURE_PAYLOAD) && in_wr) begin
            if (in_data[63:32] == 32'hCAFEBABE) begin
               bram_ann_addr <= 8'hFF;  
            end
            if (in_data[63:32] == 32'hFACEC0DE) begin
               stop_ann_capture <= 1'b1;
            end
         end
         
         if ((state == CAPTURE_PAYLOAD) && in_wr && ann_payload_flag && !stop_ann_capture && 
             (in_data[63:32] != 32'hFACEC0DE) && 
             (in_data[63:32] != 32'hC0DEFACE) && 
             (in_data[63:32] != 32'hCAFEBABE)) begin
            
            bram_ann_data <= in_data; 
            bram_ann_we <= 1'b1;
            bram_ann_addr <= bram_ann_addr + 1'b1;
         end
         
         if (set_start_addr) pkt_start_addr <= tail;
         if (set_end_addr || full) pkt_end_addr <= tail;

         if (((state == START) && set_start_addr) || (((state == CAPTURE_HEADER) || (state == CAPTURE_PAYLOAD)) && !full) && in_wr) tail <= tail_next;
         if ((state == FLUSH) && (out_rdy && !empty)) head <= head_next;
         
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
   
   wire [31:0] hw_result_addr = {22'd0, result_addr};
   
   generic_regs
   #( 
      .UDP_REG_SRC_WIDTH   (UDP_REG_SRC_WIDTH),
      .TAG                 (`NETWORK_MEM_BLOCK_ADDR),          
      .REG_ADDR_WIDTH      (`NETWORK_MEM_REG_ADDR_WIDTH),      
      .NUM_COUNTERS        (0),                                
      .NUM_SOFTWARE_REGS   (3),                                
      .NUM_HARDWARE_REGS   (15)                               
   ) module_regs (
      .reg_req_in       (reg_req_in),
      .reg_ack_in       (reg_ack_in),
      .reg_rd_wr_L_in   (reg_rd_wr_L_in),
      .reg_addr_in      (reg_addr_in),
      .reg_data_in      (reg_data_in),
      .reg_src_in       (reg_src_in),

      .reg_req_out      (reg_req_out),
      .reg_ack_out      (reg_ack_out),
      .reg_rd_wr_L_out  (reg_rd_wr_L_out),
      .reg_addr_out     (reg_addr_out),
      .reg_data_out     (reg_data_out),
      .reg_src_out      (reg_src_out),

      .counter_updates  (),
      .counter_decrement(),

      .software_regs    ({mem_ann_addr, mem_addr, command_reg}),

      .hardware_regs    ({hw_result_addr, mem_ann_data_1, mem_ann_data_0, out_wr_ct_debug, curr_state_debug, payload_cycles_debug, tail_ptr_debug, head_ptr_debug, first_data_debug, flag, pkt_end_debug, pkt_start_debug, mem_ctrl, mem_data_msb, mem_data_lsb}),

      .clk              (clk),
      .reset            (reset)
    );

endmodule