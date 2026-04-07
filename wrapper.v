`timescale 1ns/1ps

module wrapper
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


wire [63:0]    mem_din_debug;
wire [31:0]    mem_addr_debug,command_reg;
assign dmem_web         =     command_reg[2];                           // This means we write 0x0c for dmem write (debug mode not strictly required due to dedicated debug port)
assign debug            =     command_reg[3];                           // This means we write 0x08 for debug enable


wire [63:0] mem_out;
wire [63:0] mem_out_b;
wire start_signal;
wire gpu_done_signal;
wire [9:0] cpu_addr, gpu_addr;
wire [9:0] mem_addr = (start_signal&(~gpu_done_signal))? gpu_addr : cpu_addr;
wire [63:0] cpu_din, gpu_din;
wire [63:0] mem_din = (start_signal&(~gpu_done_signal))? gpu_din : cpu_din;
wire cpu_we, gpu_we;
wire [9:0] mem_we = (start_signal&(~gpu_done_signal))? gpu_we : cpu_we;

wire [15:0] vec_size;

data_memory gpu_dmem(
	.addra(mem_addr),             // Port A is for reading from EX
	.addrb(mem_addr_debug[9:0]),    // Port B is for register interface
	.clka(clk),
	.clkb(clk),
	.dina(mem_din),
	.dinb(mem_din_debug),
	.douta(mem_out),
	.doutb(mem_out_b),
	.wea(mem_we),
	.web(dmem_web) 
);



      wire                               cpu_reg_req_in;
      wire                               cpu_reg_ack_in;
      wire                               cpu_reg_rd_wr_L_in;
      wire  [`UDP_REG_ADDR_WIDTH-1:0]    cpu_reg_addr_in;
      wire  [`CPCI_NF2_DATA_WIDTH-1:0]   cpu_reg_data_in;
      wire  [UDP_REG_SRC_WIDTH-1:0]      cpu_reg_src_in;

      wire                              cpu_reg_req_out;
      wire                              cpu_reg_ack_out;
      wire                              cpu_reg_rd_wr_L_out;
      wire  [`UDP_REG_ADDR_WIDTH-1:0]   cpu_reg_addr_out;
      wire  [`CPCI_NF2_DATA_WIDTH-1:0]  cpu_reg_data_out;
      wire  [UDP_REG_SRC_WIDTH-1:0]     cpu_reg_src_out;

wire [31:0] exla, str_logic_analyzer,imem_logic_analyzer,pc_logic_analyzer,current_iteration,imem_dout;
wire [63:0] rs2_logic_analyzer, rs1_logic_analyzer, wbrd_logic_analyzer, alu_logic_analyzer,wb_rd_data_mux_out,rs1_d,dmem_dout_reg;

gpu gpu_inst(.clk(clk),
	     .reset(reset),
	     .vec_size(vec_size),
	     .start(start_signal),
	     .done(gpu_done_signal),
	     .mem_addr(gpu_addr),
	     .mem_din(gpu_din),
	     .dmem_dout(mem_out),
	     .mem_we_out(gpu_we),
	     .command_reg(command_reg),
	     .mem_din_debug(mem_din_debug),
	     .mem_addr_debug(mem_addr_debug),
	    // .done(done,
	     .exla(exla),			        			                .str_logic_analyzer(str_logic_analyzer),
	     .rs2_logic_analyzer(rs2_logic_analyzer),
	     .rs1_logic_analyzer(rs1_logic_analyzer),
	     .wbrd_logic_analyzer(wbrd_logic_analyzer),
	     .alu_logic_analyzer(alu_logic_analyzer),
	     .imem_logic_analyzer(imem_logic_analyzer),
	     .pc_logic_analyzer(pc_logic_analyzer),
	     .wb_rd_data_mux_out(wb_rd_data_mux_out),
	     .current_iteration(current_iteration),
	     .rs1_d_out(rs1_d),
	     .dmem_dout_reg(dmem_dout_reg),  
	     .imem_dout(imem_dout)
	     );

wire [31:0] cpu_imem_dout;

cpu cpu_inst(.clk(clk),
	     .reset(reset),
	     .gpu_start(start_signal),
             .mem_we(cpu_we),
             .mem_dout(mem_out),
             .mem_din(cpu_din),
             .mem_addr_in(cpu_addr),
	     .gpu_done(gpu_done_signal),
	     .vec_size(vec_size),
	     .command_reg(command_reg),
	     .mem_din_debug(mem_din_debug),
	     .mem_addr_debug(mem_addr_debug),
	     .imem_dout_out(cpu_imem_dout)


    );

generic_regs
   #( 
      .UDP_REG_SRC_WIDTH   (UDP_REG_SRC_WIDTH),
      .TAG                 (`WRAPPER_BLOCK_ADDR),          // Tag -- eg. MODULE_TAG
      .REG_ADDR_WIDTH      (`WRAPPER_REG_ADDR_WIDTH),     // Width of block addresses -- eg. MODULE_REG_ADDR_WIDTH
      .NUM_COUNTERS        (0),                 // Number of counters
      .NUM_SOFTWARE_REGS   (4),                 // Number of sw regs
      .NUM_HARDWARE_REGS   (20)                  // Number of hw regs
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
      .software_regs    ({ 
                           mem_din_debug[63:32], 
                           mem_din_debug[31:0], 
                           mem_addr_debug, 
                           command_reg
                           }),

      // --- HW regs interface
      .hardware_regs    ({ 
			  cpu_imem_dout,
                          str_logic_analyzer,
                          rs2_logic_analyzer[63:32],
                          rs2_logic_analyzer[31:0],
                          rs1_logic_analyzer[63:32],
                          rs1_logic_analyzer[31:0],
                          wbrd_logic_analyzer[63:32],
                          wbrd_logic_analyzer[31:0],
                          alu_logic_analyzer[63:32],
                          alu_logic_analyzer[31:0],
                          imem_logic_analyzer,
                          pc_logic_analyzer,
                          wb_rd_data_mux_out[63:32],
                          wb_rd_data_mux_out[31:0],
                          current_iteration,
			  rs1_d[63:32],
                          rs1_d[31:0],
                          imem_dout,
			   mem_out_b[63:32],
			   mem_out_b[31:0]          // HW REG  1 - DMEM debug port B
                        }),

      .clk              (clk),
      .reset            (reset)
    );

endmodule
