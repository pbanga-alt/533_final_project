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
module wrap
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
      output wire                         in_rdy
	 
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

wire [9:0] w_a_from_tensor_to_mem, i_a_from_tensor_to_mem;
wire [63:0] i_data, w_data;

wire [9:0] cpu_addr, gpu_addr;
wire [9:0] else_addr_a = (start_signal&(~gpu_done_signal))? ((tpu_start&(~tpu_done)) ? w_a_from_tensor_to_mem : gpu_addr) : cpu_addr;
wire [9:0] else_addr_b = (tpu_start&(~tpu_done)) ? i_a_from_tensor_to_mem :  10'd0; //mem_addr_debug[9:0];
wire [63:0] cpu_din, gpu_din;
wire [63:0] else_din_a = (start_signal&(~gpu_done_signal))? gpu_din : cpu_din;
wire cpu_we, gpu_we;
wire [9:0] else_we_a = (start_signal&(~gpu_done_signal))? gpu_we : cpu_we;
wire cpu_start;
reg cpu_reset;
wire [15:0] vec_size;
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
wire [9:0] w_a_in;
wire [9:0] i_a_in;
wire bypass_adder, bypass_relu;
wire [63:0] CG_mem_rd_data;
wire [9:0] inter_addr;
wire first_hidden_layer,final_layer;

tensor_unit_in64 tensor(.clk(clk),
						 .rst(reset|tpu_reset),
						 .w_a_in(w_a_in),   // parameter
			    		 .i_a_in(i_a_in),   // parameter
						 .start(tpu_start),
						 .bypass_adder(bypass_adder),  //parameter
						 .bypass_relu(bypass_relu),    //parameter
						 .weight_address(w_a_from_tensor_to_mem),   
						 .inputs_address(i_a_from_tensor_to_mem),   
						 .input_layer_in(mem_out_b),
						 .weights_in(CG_mem_rd_data),
						 .input_count(in_count), //parameter
						 .layer_count(w_count),  //parameter
						 .done(tpu_done),
						 .intermediate_address(inter_addr),
						 		  .first_hidden_layer(first_hidden_layer),
		  .final_layer(final_layer)
							);
						 
gpu2 gpu_inst(.clk(clk),
	     .reset(reset|gpu_reset),
	     .vec_size(vec_size),
	     .start(start_signal),
	     .done(gpu_done_signal),
	     .mem_addr(gpu_addr),
	     .mem_din(gpu_din),
	     .dmem_dout(mem_out),
	     .mem_we_out(gpu_we),
		  .command_reg(1),
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
		  .final_layer(final_layer)
	    // .done(done,
	     );
		  
wire [31:0] cpu_imem_dout;

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
		  		  .command_reg(1),
				  .local_gpu_reset(gpu_reset),
				  .cpu_done(cpu_done)
	

    );

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
  //  .state(state),
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
  .debug_dmem(1'b0),
  .debug_dmem_addr(10'd0)
  //NOT FOR SIM  .debug_dmem_data_low(w_fifo_dmem_rdata_low),
  //NOT FOR SIM  .debug_dmem_data_mid(w_fifo_dmem_rdata_mid),
  //NOT FOR SIM  .debug_dmem_data_high(w_fifo_dmem_rdata_high)
  ); 
  
endmodule
