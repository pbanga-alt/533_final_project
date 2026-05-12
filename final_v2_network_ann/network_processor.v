`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    00:26:10 03/09/2026 
// Design Name: 
// Module Name:    wrap 
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
module network_processor 
	 #(
	 parameter DATA_WIDTH       = 64,
	 parameter CTRL_WIDTH       = 8,
    parameter FIFO_DEPTH_WORDS = 256,
	 parameter UDP_REG_SRC_WIDTH = 2
	 )(
      input                                reset,
      input                                clk,
		output wire [DATA_WIDTH-1:0]        out_data,
      output wire [CTRL_WIDTH-1:0]        out_ctrl,
      output wire                         out_wr,
      input                               out_rdy,

    // --- Data path interface (input)
      input      [DATA_WIDTH-1:0]         in_data,
      input      [CTRL_WIDTH-1:0]         in_ctrl,
      input                               in_wr,
      output wire                         in_rdy,
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
      output  [UDP_REG_SRC_WIDTH-1:0]     reg_src_out

	 
   );


wire [63:0]    mem_din_debug;
wire [31:0]    mem_addr_debug,command_reg;
assign dmem_web         =     command_reg[2];                           // This means we write 0x0c for dmem write (debug mode not strictly required due to dedicated debug port)
assign debug            =     command_reg[3];                           // This means we write 0x08 for debug enable

wire gpu_reset;
wire tpu_reset;
wire tpu_done;
wire tpu_start;
wire cpu_done;
wire [63:0] mem_out;
wire [63:0] mem_out_b;
wire start_signal;
wire gpu_done_signal;
wire [63:0] tpu_din;
wire tpu_wen;
wire [9:0] tpu_write_addr;
wire [9:0] w_a_from_tensor_to_mem, i_a_from_tensor_to_mem;
wire [63:0] i_data, w_data;

wire [9:0] tpu_mem_write_addr;
wire [9:0] result_addr;
wire [9:0] cpu_addr, gpu_addr;
wire [9:0] else_addr_a = (start_signal&(~gpu_done_signal))? ((tpu_start&(~tpu_done)) ? w_a_from_tensor_to_mem : gpu_addr) : cpu_addr;
wire [9:0] else_addr_b = (tpu_start&(~tpu_done)) ? tpu_wen ? result_addr : i_a_from_tensor_to_mem :  10'd0; //mem_addr_debug[9:0];
wire [63:0] cpu_din, gpu_din;
wire [63:0] else_din_a = (start_signal&(~gpu_done_signal))? gpu_din : cpu_din;
wire cpu_we, gpu_we;
wire [9:0] else_we_a = (start_signal&(~gpu_done_signal))? gpu_we : cpu_we;
wire cpu_start;
reg cpu_reset;
wire [14:0] vec_size;
wire tpu_working = tpu_start&(~tpu_done);
wire cpu_working = cpu_start&(~cpu_done);
wire gpu_working = start_signal&(~gpu_done_signal);
//data_memory gpu_dmem(
//	.addra(mem_addr),             // Port A  = cpu,gpu,tpu
//	.addrb(mem_addr_b),           // Port B is for network fifo, tpu, debug
//	.clka(clk),
//	.clkb(clk),
//	.dina(mem_din),
//	.dinb(mem_din_debug),
//	.douta(mem_out),
//	.doutb(mem_out_b),
//	.wea(mem_we),
//	.web(dmem_web) 
//);

reg mem_port_master;
wire[31:0] processor_status;
reg [11:0] addr_calc;
wire [2:0] state;
//reg 
   instruction_memory np_outside_la (
		.clka(clk), 
		.clkb(clk), 
		.dina({9'b0,in_rdy,cpu_reset,cpu_start,mem_port_master,tpu_working,gpu_working,cpu_working,state}),    
		.dinb(32'd0),
		.addra(addr_calc),
		.addrb(mem_addr_debug[11:0]),        	      
		.wea(1'b1),
		.web(1'b0),      	      
		.douta(),       	      
		.doutb(processor_status)         	      
	);

always@(posedge clk) begin
	if(reset) addr_calc <= 12'd0;
	else
	begin
	if(addr_calc < 2000 && state > 3'd0) begin
		addr_calc <= addr_calc + 1;
	end
	end
end	
 always@(*) begin
	 if(in_rdy || cpu_done)
		 mem_port_master = 1'b0;
    else if(tpu_working || cpu_working || gpu_working)
		 mem_port_master = 1'b1;
	 else mem_port_master = 1'b0; 
 end
 
 always@(*) begin
	if(cpu_start) cpu_reset = 0;
	else cpu_reset = 1;
 end


wire [31:0] exla, str_logic_analyzer,imem_logic_analyzer,pc_logic_analyzer,current_iteration,imem_dout;
wire [63:0] rs2_logic_analyzer, rs1_logic_analyzer, wbrd_logic_analyzer, alu_logic_analyzer,wb_rd_data_mux_out,rs1_d,dmem_dout_reg;


wire [11:0] in_count, w_count;
wire [13:0] w_a_in;
wire [9:0] i_a_in;
wire bypass_adder, bypass_relu;
wire [63:0] CG_mem_rd_data;
wire [13:0] inter_addr;
wire first_hidden_layer,final_layer;
wire [63:0] input_mem_out;
wire [9:0] input_addr_in;

//inputs_mem inputm(.addr(input_addr_in[6:0]),
//	.clk(clk),
//	.din(64'd0),
//	.dout(input_mem_out),
//	.we(1'b0));
	
wire [63:0] weights_in;
wire [13:0] weight_address;

wire [13:0]  wb_mem_decision = debug ? mem_addr_debug[13:0] : weight_address;
wire wb_mem_en_decision = (debug & command_reg[5]) ? 1'b1 : 1'b0;

	tpu_weights_biases_mem tpu1(.addr(wb_mem_decision),
	.clk(clk),
	.din(mem_din_debug),
	.dout(weights_in),
	.we(wb_mem_en_decision));

wire [3:0] current_state;
wire [63:0] reg_out;
wire [63:0] state_out;
wire [63:0] mac_logic_analyzer, add_logic_analyzer, relu_logic_analyzer,inlayer_logic_analyzer,wlayer_logic_analyzer;
wire [31:0] tpu_count_la, tpu_start_done_la,tpu_addr_la, bypass_layer_info_la;
tensor_unit_wb tensor(
				.clk(clk),
						 .rst(reset|tpu_reset),
						 .w_a_in(w_a_in),   // parameter
			    		 .i_a_in(i_a_in),   // parameter
						 .start(tpu_start),
						 .debug(debug),
						 .mem_addr_debug(mem_addr_debug),
						 .bypass_adder(bypass_adder),  //parameter
						 .bypass_relu(bypass_relu),    //parameter
						 .weight_address(weight_address),   
						 .inputs_address(input_addr_in),   
						 .input_layer_in(input_mem_out),
						 .weights_in(weights_in),
						 .input_count(in_count), //parameter
						 .layer_count(w_count),  //parameter
						 .done(tpu_done),
						 .intermediate_address(inter_addr),
						 		  .first_hidden_layer(first_hidden_layer),
								  .tpu_din(tpu_din),
								  .tpu_mem_write_addr(tpu_mem_write_addr),
								  .tpu_wen(tpu_wen),
		  .final_layer(final_layer),
						 .reg_out(reg_out),
						 .state_out(state_out),
						 .mac_logic_analyzer(mac_logic_analyzer),
						 .add_logic_analyzer(add_logic_analyzer),
						 .relu_logic_analyzer(relu_logic_analyzer),
						 .inlayer_logic_analyzer(inlayer_logic_analyzer),
						.weightlayer_logic_analyzer(wlayer_logic_analyzer),
						.current_state(current_state)
							);
wire [31:0] cpu_status, gpu_status;
				 
gpu2 gpu_inst(.clk(clk),
	     .reset(reset|gpu_reset),
	     .vec_size(vec_size),
	     .start(start_signal),
	     .done(gpu_done_signal),
	     .mem_addr(gpu_addr),
	     .mem_din(gpu_din),
	     .dmem_dout(mem_out),
	     .mem_we_out(gpu_we),
		  .command_reg(command_reg),
//
	     .mem_din_debug(mem_din_debug),
	     .mem_addr_debug(mem_addr_debug),
	    // .done(done,
	     .exla(exla),			        			               
// .str_logic_analyzer(str_logic_analyzer),
	//     .wbrd_logic_analyzer(wbrd_logic_analyzer),
	//     .alu_logic_analyzer(alu_logic_analyzer),
	//     .imem_logic_analyzer(imem_logic_analyzer),
	     .pc_logic_analyzer(pc_logic_analyzer),
	     .wb_rd_data_mux_out(wb_rd_data_mux_out),
	     .current_iteration(current_iteration),
	     .rs1_d_out(rs1_d),
	     .dmem_dout_reg(dmem_dout_reg),  
	     .imem_dout(imem_dout),
//

		  .tpu_start_out(tpu_start),
		  .local_tpu_reset(tpu_reset),
		  .tpu_done(tpu_done),
		  .w_addr_in(w_a_in),
		  .i_addr_in(i_a_in),
	     .bypass_add(bypass_adder),
		  .bypass_relu(bypass_relu),
		  .in_count(in_count),
		  .w_count(w_count),
		  .from_tpu_intermediate_address(inter_addr),
		  .first_hidden_layer(first_hidden_layer),
		  .final_layer(final_layer),
		  .gpu_status(gpu_status)
	    // .done(done,
	     );
		  
wire [31:0] cpu_imem_dout;
wire [31:0] cpu_pc_la;
wire [63:0] cpu_r1_data;
wire [31:0] imem_out_la;

cpu2 cpu_inst(.clk(clk),
	     .reset(reset|cpu_reset),
	     .gpu_start(start_signal),
             .mem_we(cpu_we),
             .mem_dout(mem_out),
             .mem_din(cpu_din),
             .mem_addr_in(cpu_addr),
	     .gpu_done(gpu_done_signal),
	     .vec_size(vec_size),
		  .start_mem_pointer_to_gpu(start_mem_cpu_to_gpu),
		  .stop_mem_pointer_to_gpu(stop_mem_cpu_to_gpu),
	     .mem_din_debug(mem_din_debug),
	     .mem_addr_debug(mem_addr_debug),
	     .imem_dout_out(cpu_imem_dout),
		  		  .command_reg(command_reg),
				  .local_gpu_reset(gpu_reset),
				  .cpu_done(cpu_done),
	     .pc_la(cpu_pc_la),
	     .r1_data(cpu_r1_data),
	     .cpu_status(cpu_status),
	     .imem_out_la(imem_out_la)

    );

wire [31:0] w_fifo_dmem_rdata_low, w_fifo_dmem_rdata_mid, w_fifo_dmem_rdata_high;

wire [31:0] fifo_status;
wire [31:0] result_addr_debug = {22'b0,result_addr};
single_packet_fifo_2 #( 
    .DATA_WIDTH(DATA_WIDTH),
    .CTRL_WIDTH(CTRL_WIDTH),
    .FIFO_DEPTH_WORDS(FIFO_DEPTH_WORDS)
  ) fifo_instance(
  	 .port_master(mem_port_master), // fifo or else(cpu or gpu or tpu)
    .out_data(out_data),
    .out_ctrl(out_ctrl),
    .out_wr(out_wr),
    .out_rdy(out_rdy),

    .in_data(in_data),
    .in_ctrl(in_ctrl),
    .in_wr(in_wr),
    .in_rdy(in_rdy),
	 .tpu_working(tpu_working),
	 .tpu_mem_write_addr(tpu_mem_write_addr),
	 .tpu_din(tpu_din),
	 .tpu_wen(tpu_wen),
    .state(state),
    .freeze(cpu_done),   //to be generated via cpu done //freeze logic to be implemented if this doesnt work
    .clk(clk),
    .reset(reset),
    .cpu_start_process(cpu_start),  // to be implemented in cpu

    .else_addr_in_a(else_addr_a),
	 .else_addr_in_b(else_addr_b),
    .else_data_in_a(else_din_a), 
    .cpu_in_ctrl(8'd0), 
    .else_we_a(else_we_a), 
    .CG_out_data(CG_mem_rd_data),
	 .tpu_port_b_out(mem_out_b),
    .CG_out_ctrl(),
  //  .cpu_en(cpu_mem_en), not used
	 
  //	 .gpu_addr(gpu_mem_addr), -> no need
  //  .gpu_in_data(gpu_mem_wr_data), -> no need
    .gpu_in_ctrl(8'd0),
  //  .gpu_we(gpu_mem_we), -> no need
  //  .gpu_en(gpu_mem_en), -> // flashing cpu, gpu imem , no need
  .debug_dmem(command_reg[3]),
  .debug_dmem_addr(mem_addr_debug),
  .debug_dmem_data_low(w_fifo_dmem_rdata_low),
  .debug_dmem_data_mid(w_fifo_dmem_rdata_mid),
  .debug_dmem_data_high(w_fifo_dmem_rdata_high),
  .fifo_status(fifo_status),
.mem_addr_debug(mem_addr_debug),
.tpu_input_addr_in(input_addr_in),
.tpu_input_mem_out(input_mem_out),
.result_addr(result_addr)

  ); 
generic_regs
   #( 
      .UDP_REG_SRC_WIDTH   (UDP_REG_SRC_WIDTH),
      .TAG                 (`NETWORK_PROCESSOR_BLOCK_ADDR),          // Tag -- eg. MODULE_TAG
      .REG_ADDR_WIDTH      (`NETWORK_PROCESSOR_REG_ADDR_WIDTH),     // Width of block addresses -- eg. MODULE_REG_ADDR_WIDTH
      .NUM_COUNTERS        (0),                 // Number of counters
      .NUM_SOFTWARE_REGS   (4),                 // Number of sw regs
      .NUM_HARDWARE_REGS   (27)                  // Number of hw regs
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
      .hardware_regs    ( {processor_status,
			   fifo_status,
		           gpu_status,
			   cpu_status,
			   state_out[31:0],
			   mac_logic_analyzer[63:32],
			   mac_logic_analyzer[31:0],
			   add_logic_analyzer[63:32],
			   add_logic_analyzer[31:0],
			   inlayer_logic_analyzer[63:32],
			   inlayer_logic_analyzer[31:0],
			   wlayer_logic_analyzer[63:32],
			   wlayer_logic_analyzer[31:0],
			   reg_out[63:32],
			   reg_out[31:0],	
			  w_fifo_dmem_rdata_low,
			 w_fifo_dmem_rdata_mid,
			w_fifo_dmem_rdata_high,
			  cpu_pc_la,
                          result_addr_debug,
                          input_mem_out[63:32],
                          input_mem_out[31:0],
                          pc_logic_analyzer,
			  weights_in[63:32],
                          weights_in[31:0],
			   mem_out_b[63:32],
			   mem_out_b[31:0]          // HW REG  1 - DMEM debug port B
                        }),

      .clk              (clk),
      .reset            (reset)
    );
  
endmodule
