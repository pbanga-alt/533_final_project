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

      // input [9:0] cpu_addr_in,
      // input cpu_we,
		// input done_process,
		// output [1:0] state_out,
		// output [9:0] start_addr_out,
		// output [9:0] end_addr_out,
      
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
      output  [`UDP_REG_ADDR_WIDTH-1:0]   reg_addr_out,
      output  [`CPCI_NF2_DATA_WIDTH-1:0]  reg_data_out,
      output  [UDP_REG_SRC_WIDTH-1:0]     reg_src_out,

      // misc
      input                                reset,
      input                                clk
   );

   // assign reg_req_out = reg_req_in;
   // assign reg_ack_out = reg_ack_in;
   // assign reg_rd_wr_L_out = reg_rd_wr_L_in;
   // assign reg_addr_out = reg_addr_in;
   // assign reg_data_out = reg_data_in;
   // assign reg_src_out = reg_src_in;


    // local parameter
   parameter                     START = 3'b000;
   parameter                     CAPTURE_HEADER = 3'b001;
   parameter                     CAPTURE_PAYLOAD= 3'b010;
   parameter                     PROCESS = 3'b011;
   parameter                     FLUSH = 3'b100;

   // internal signals
   reg [2:0] state, state_next;

   reg set_start_addr, set_end_addr;

   reg [9:0] head, tail;   //head points to read addr, tail points to next first empty addr where data will be written
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
   wire done_process;
   wire [9:0] cpu_addr_in;
   reg cpu_we;
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
	// --- 128-bit BRAM CPU Extraction Wires ---
   wire [127:0] conv_doutb; // Output data to convolution engine
   wire [31:0] mem128_addr;        // Software reg: CPU writes the address it wants to read
   wire [31:0] mem128_data_0;      // Hardware reg: 128-bit data [31:0]
   wire [31:0] mem128_data_1;      // Hardware reg: 128-bit data [63:32]
   wire [31:0] mem128_data_2;      // Hardware reg: 128-bit data [95:64]
   wire [31:0] mem128_data_3;      // Hardware reg: 128-bit data [127:96]

   // Map the 128-bit BRAM output (conv_doutb) to the 32-bit hardware registers
   assign mem128_data_0 = conv_doutb[31:0];
   assign mem128_data_1 = conv_doutb[63:32];
   assign mem128_data_2 = conv_doutb[95:64];
   assign mem128_data_3 = conv_doutb[127:96];

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

	// assign state_out = state;
	// assign start_addr_out = pkt_start_addr;
	// assign end_addr_out = pkt_end_addr;
   assign done_process = 1;
   reg [9:0] counter;
   reg [9:0] counter_next;
   reg [9:0] payload_start_addr;
   assign cpu_addr_in = (command_reg[2:0] == 3'b001) ? mem_addr : (payload_start_addr + counter);   // modify at bram addr 07
   //assign cpu_we = 0;
   reg [63:0] dummy_data_in;
   reg payload_flag;
   reg payload_flag_next;
	
	// --- New 128-bit BRAM Signals ---
   reg [63:0]  half_word_reg;    // Buffer for the first 64-bit chunk
   reg         toggle_128b;      // 0 = waiting for 1st half, 1 = waiting for 2nd half
   
   reg [8:0]   bram_128b_addr;   // Address counter for the new BRAM
   reg         bram_128b_we;     // Write enable for the new BRAM
   reg [127:0] bram_128b_data;   // Concatenated 128-bit data

   
   // -----------------------------------------vSTART LOGIC ------------------------------------------------------------
   FIFO_bram FIFO_bram_i (
      .addra(fifo_addr_in),   // FOR FIFO OP
      .addrb(cpu_addr_in),    // DMEM ACCESS FROM CPU
      .clka (clk),
      .clkb (clk),
      .dina({in_ctrl, in_data}),
      .dinb({cpu_ctrl_in, cpu_data_in}),
      .douta({out_ctrl, out_data}),
      .doutb({cpu_ctrl_out, cpu_data_out}),
		.ena(1'b1),
      .wea(fifo_we),    // in_wr && fifo_we
      .web(cpu_we)
   );
	
	// --- 128-bit Activation BRAM ---
   
   
   activation_mem activation_bram_i (
      .addra (bram_128b_addr),      
      .addrb (mem128_addr[8:0]),    // Connect Port B address to the new SW register
      .clka  (clk),
      .clkb  (clk),
      .dina  (bram_128b_data),      
      .dinb  (128'd0),              
      .douta (),                    
      .doutb (conv_doutb),          // 128-bit data out to HW registers
      .ena   (1'b1),                
      .enb   (1'b1),                // Ensure Port B is enabled for CPU reads
      .wea   (bram_128b_we),        
      .web   (1'b0)                 
   );

   always @(*) begin
      case(counter)
         10'd1 : dummy_data_in = 64'hFFFFFFFFFFFFFF9C;
         10'd2 : dummy_data_in = 64'hFFFFFFFFFFFFFFD6;
         default : dummy_data_in = 64'd00;
      endcase

   end
   

   // State machine / controller
   always @(*) begin
      state_next = state;
      fifo_we = 0;
      set_start_addr = 0;
      set_end_addr = 0;

      cpu_data_in = 0;
      cpu_ctrl_in = 0;
      cpu_we = 0;

      //test
      pkts_ct_next = pkts_ct;
      counter_next = counter;
      payload_flag_next = payload_flag;

      case (state)
         START: begin
            if (in_wr && (in_ctrl != 0)) begin
               state_next = CAPTURE_HEADER;
               fifo_we = 1;
               set_start_addr = 1;
               pkts_ct_next = pkts_ct + 1; // TEST
            end
            counter_next = 8'd1;
            payload_flag_next = 0;
         end
         CAPTURE_HEADER: begin
            if (in_wr && (in_ctrl == 0)) begin
               state_next = CAPTURE_PAYLOAD;
               set_end_addr = 1;             // DONT THINK THIS SHOULD BE HERE
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
            if (in_data[63:32] == 32'hC0DEFACE) payload_flag_next = 1;
         end
         PROCESS : begin
            if ((counter == 8'd2) || (payload_flag != 1)) begin
               state_next = FLUSH;
            end
            cpu_data_in = dummy_data_in;
            cpu_ctrl_in = cpu_ctrl_out;
            cpu_we = payload_flag;
            counter_next = counter + 1;
         end
         FLUSH : begin
            if (head == pkt_end_addr) begin
               state_next = START;
            end
         end
      endcase
   end
   reg         stop_128b_capture;
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
         pkts_ct <= 0;
         payload_cycles_reg <= 0;
         out_wr_ct_reg <= 0;

         counter <= 8'd1;
         payload_flag <= 0;
			
			toggle_128b <= 0;
         bram_128b_addr <= 0;
         bram_128b_we <= 0;
         half_word_reg <= 0;
         bram_128b_data <= 0;
			stop_128b_capture <= 0;

      end else begin
         state <= state_next;
			bram_128b_we <= 0;
			
			if (state == START) begin
            toggle_128b <= 0;
            stop_128b_capture <= 0;
         end
			if ((state == CAPTURE_PAYLOAD) && in_wr) begin
				if (in_data[63:32] == 32'hCAFEBABE) begin
					bram_128b_addr <= -1;  // Initialize to -1
					toggle_128b <= 1'b0;       // Ensure the concatenation toggle is reset
				end
				if (in_data[63:32] == 32'hFACEC0DE) begin
					stop_128b_capture <= 1'b1;
				end
			end
         // Capture logic during the payload phase
         if ((state == CAPTURE_PAYLOAD) && in_wr && payload_flag && !stop_128b_capture &&(in_data[63:32] != 32'hFACEC0DE)) begin
            if (toggle_128b == 1'b0) begin
               // Store the first 64 bits and flip the toggle
               half_word_reg <= in_data;
               toggle_128b <= 1'b1;
            end else begin
               
               bram_128b_data <= {half_word_reg, in_data}; 
               
               bram_128b_we <= 1'b1;
               bram_128b_addr <= bram_128b_addr + 1'b1;
               
               // Reset toggle for the next 128-bit pair
               toggle_128b <= 1'b0;
            end
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
         pkts_ct <= pkts_ct_next;
         first_data_reg <= (set_start_addr) ? in_data[31:0] : first_data_reg;
         payload_cycles_reg <= ((state == CAPTURE_PAYLOAD) && (payload_cycles_reg != 32'hffffffff)) ? payload_cycles_reg + 1 : payload_cycles_reg;
         out_wr_ct_reg <= (out_wr && (out_wr_ct_reg != 32'hffffffff)) ? out_wr_ct_reg + 1 : out_wr_ct_reg;

         if ((state == PROCESS) || (state == START)) counter <= counter_next;
         payload_flag <= payload_flag_next;
         if (in_data[63:32] == 32'hC0DEFACE) payload_start_addr <= tail;
      end
   end
   
   
	generic_regs
   #( 
      .UDP_REG_SRC_WIDTH   (UDP_REG_SRC_WIDTH),
      .TAG                 (`NETWORK_MEM_BLOCK_ADDR),          // Tag -- eg. MODULE_TAG
      .REG_ADDR_WIDTH      (`NETWORK_MEM_REG_ADDR_WIDTH),      // Width of block addresses -- eg. MODULE_REG_ADDR_WIDTH
      .NUM_COUNTERS        (0),                                // Number of counters
      .NUM_SOFTWARE_REGS   (3),                                // INCREASED: Now 3 SW regs
      .NUM_HARDWARE_REGS   (16)                                // INCREASED: Now 16 HW regs
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

      // --- counters interface
      .counter_updates  (),
      .counter_decrement(),

      // --- SW regs interface
      // ADDED: mem128_addr at the top
      .software_regs    ({mem128_addr, mem_addr, command_reg}),

      // --- HW regs interface
      // ADDED: mem128_data_3 down to 0 at the top
      .hardware_regs    ({mem128_data_3, mem128_data_2, mem128_data_1, mem128_data_0, out_wr_ct_debug, curr_state_debug, payload_cycles_debug, tail_ptr_debug, head_ptr_debug, first_data_debug, flag, pkt_end_debug, pkt_start_debug, mem_ctrl, mem_data_msb, mem_data_lsb}),

      .clk              (clk),
      .reset            (reset)
    );


endmodule
