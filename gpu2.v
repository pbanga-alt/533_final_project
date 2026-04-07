`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    17:12:09 03/09/2026 
// Design Name: 
// Module Name:    gpu2 
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
module gpu2  #(
      parameter DATA_WIDTH = 64,
      parameter CTRL_WIDTH = DATA_WIDTH/8,
      parameter UDP_REG_SRC_WIDTH = 2
   )
   (
  				input clk,
				input reset,
			//	input func_args_memory_pointer,
			//	input number_of_arguments_passed,
				input [14:0] vec_size,
				input start,
			        output done,
				output [9:0] mem_addr,
				output [63:0] mem_din,
				input [63:0] dmem_dout,
				output mem_we_out,
				input [31:0] command_reg,
				input [63:0] mem_din_debug,
				input [31:0] mem_addr_debug,
		   		//output [31:0] done,
			        output [31:0] exla,			        			    output [31:0] str_logic_analyzer,
			        output [63:0] rs2_logic_analyzer,
			        output [63:0] rs1_logic_analyzer,
			        output [63:0] wbrd_logic_analyzer,
			        output [63:0] alu_logic_analyzer,
			        output [31:0] imem_logic_analyzer,
			        output [31:0] pc_logic_analyzer,
			        output [63:0] wb_rd_data_mux_out,
			        output [31:0] current_iteration,
			        output [63:0] rs1_d_out,
			        output [63:0]dmem_dout_reg,  
				output [31:0] imem_dout,
				//tpu control handshaking
				output reg tpu_start_out,
				output reg local_tpu_reset,
				input tpu_done,
				//tpu parameters
				output reg [9:0] w_addr_in,
				output reg [9:0] i_addr_in,
				output reg bypass_add,
				output reg bypass_relu,
				output reg [11:0] in_count,
				output reg [11:0] w_count,
				input [9:0] from_tpu_intermediate_address,
				output reg first_hidden_layer,
				output reg final_layer
	);

wire [3:0] ex_lane_mask_logic_analyzer;
assign exla = {28'd0,ex_lane_mask_logic_analyzer};
// REGISTER INTERFACE WIRES AND DECLARATIONS
//wire [63:0]    mem_din_debug;
//wire [31:0]    mem_addr_debug,command_reg;
//wire [31:0] start, done, vec_size;
wire done_out;
assign done = {30'd0,done_out};
wire [4:0] rs1_s_id, rs2_s_id, rs3_s_id;
wire [4:0] id_reg1_addr;
//Debug assignments
assign imem_we_debug    =     command_reg[4];                           // This means we write 0x0a for imem write (include debug signal for muxing)
assign dmem_web         =     command_reg[2];                           // This means we write 0x0c for dmem write (debug mode not strictly required due to dedicated debug port)
assign debug            =     command_reg[3];                           // This means we write 0x08 for debug enable
assign id_reg1_addr     =  debug? mem_addr_debug[4:0] : rs1_s_id;             //debug mux
//assign         if_pc_plus_1   =  pc_reg + 1;
wire [11:0] imem_addr;
assign         imem_addr = debug? mem_addr_debug[11:0]: 12'd0;            //debug mux
//HW REG
//wire [31:0] imem_dout;
//wire [63:0] dmem_dout_reg;
// END
wire [11:0] pc_out;
wire [3:0] lane_mask_out;
//wire [31:0] current_iteration;
wire [31:0] instr;
reg mem_wb_ret;
wire [31:0] pc_debug;
assign pc_debug = pc_out;
wire tpu_start;
reg [11:0] if_id_pc_out_reg;
gpucontrolunit IF_control_unit(
.clk(clk),
.rst(reset),
.vec_size(vec_size[14:0]),
.start(start),
.ret(mem_wb_ret),
.current_iteration(current_iteration[13:0]),
.pc_out(pc_out),
.lane_mask_out(lane_mask_out),
.done(done_out),
.id_tpu_start(tpu_start),
.tpu_done(tpu_done),
.if_id_pc_out_reg(if_id_pc_out_reg)
);

wire [11:0] to_imem_addr = (tpu_start & ~tpu_done) ? if_id_pc_out_reg : pc_out;

instruction_memory gpu_imem (
	.addra(imem_addr),         // a used for writing imem from reg interface
	.addrb(to_imem_addr),  // b used for gpu
	.clka(clk),
	.clkb(clk),
	.dina(mem_din_debug[31:0]),
	.dinb(32'd0),
	.douta(imem_dout),
	.doutb(instr),
	.wea(imem_we_debug),
	.web(1'b0)
);

reg [11:0] addr_counter;
//wire [31:0] pc_logic_analyzer;
//wire [31:0] imem_logic_analyzer;
//wire [63:0] rs1_logic_analyzer;
//wire [63:0] rs2_logic_analyzer;
//wire [3:0] ex_lane_mask_logic_analyzer;
reg [3:0] id_ex_lane_mask_reg;
reg [63:0] id_ex_rs1_s_reg;
//wire [31:0] str_logic_analyzer;
reg [63:0] id_ex_rs2_s_reg;
reg [63:0] ex_mem1_rs2_s_reg, ex_mem2_rs2_s_reg, ex_mem3_rs2_s_reg, ex_mem4_rs2_s_reg;
reg ex_mem1_we_reg, ex_mem2_we_reg, ex_mem3_we_reg, ex_mem4_we_reg;
instruction_memory logic_analyzer_str (
	.addra(addr_counter),         // a used for writing imem from reg interface
	.addrb(mem_addr_debug[11:0]),  // b used for gpu
	.clka(clk),
	.clkb(clk),
	.dina({26'd0,ex_mem4_we_reg,ex_mem4_rs2_s_reg}),
	.dinb(32'd0),
	.douta(),
	.doutb(str_logic_analyzer),
	.wea(start),
	.web(1'b0)
);
instruction_memory logic_analyzer_ex1_lane_mask (
	.addra(addr_counter),         // a used for writing imem from reg interface
	.addrb(mem_addr_debug[11:0]),  // b used for gpu
	.clka(clk),
	.clkb(clk),
	.dina(id_ex_lane_mask_reg),
	.dinb(32'd0),
	.douta(),
	.doutb(ex_lane_mask_logic_analyzer),
	.wea(start),
	.web(1'b0)
);
instruction_memory logic_analyzer_rs1_msb (
	.addra(addr_counter),         // a used for writing imem from reg interface
	.addrb(mem_addr_debug[11:0]),  // b used for gpu
	.clka(clk),
	.clkb(clk),
	.dina(id_ex_rs1_s_reg[63:32]),
	.dinb(32'd0),
	.douta(),
	.doutb(rs1_logic_analyzer[63:32]),
	.wea(start),
	.web(1'b0)
);
instruction_memory logic_analyzer_rs1_lsb (
	.addra(addr_counter),         // a used for writing imem from reg interface
	.addrb(mem_addr_debug[11:0]),  // b used for gpu
	.clka(clk),
	.clkb(clk),
	.dina(id_ex_rs1_s_reg[31:0]),
	.dinb(32'd0),
	.douta(),
	.doutb(rs1_logic_analyzer[31:0]),
	.wea(start),
	.web(1'b0)
);

instruction_memory logic_analyzer_rs2_msb (
	.addra(addr_counter),         // a used for writing imem from reg interface
	.addrb(mem_addr_debug[11:0]),  // b used for gpu
	.clka(clk),
	.clkb(clk),
	.dina(id_ex_rs2_s_reg[63:32]),
	.dinb(32'd0),
	.douta(),
	.doutb(rs2_logic_analyzer[63:32]),
	.wea(start),
	.web(1'b0)
);
instruction_memory logic_analyzer_rs2_lsb (
	.addra(addr_counter),         // a used for writing imem from reg interface
	.addrb(mem_addr_debug[11:0]),  // b used for gpu
	.clka(clk),
	.clkb(clk),
	.dina(id_ex_rs2_s_reg[31:0]),
	.dinb(32'd0),
	.douta(),
	.doutb(rs2_logic_analyzer[31:0]),
	.wea(start),
	.web(1'b0)
);

instruction_memory logic_analyzer_PC (
	.addra(addr_counter),         // a used for writing imem from reg interface
	.addrb(mem_addr_debug[11:0]),  // b used for gpu
	.clka(clk),
	.clkb(clk),
	.dina({current_iteration[12:0],4'd0,pc_out}),
	.dinb(32'd0),
	.douta(),
	.doutb(pc_logic_analyzer),
	.wea(start),
	.web(1'b0)
);

instruction_memory logic_analyzer_imem (
	.addra(addr_counter),         // a used for writing imem from reg interface
	.addrb(mem_addr_debug[11:0]),  // b used for gpu
	.clka(clk),
	.clkb(clk),
	.dina(instr),
	.dinb(32'd0),
	.douta(),
	.doutb(imem_logic_analyzer),
	.wea(start),
	.web(1'b0)
);

//wire [63:0] alu_logic_analyzer;
//wire [63:0] wbrd_logic_analyzer;
//wire [63:0] wb_rd_data_mux_out;
wire [63:0] exec_alu_out;

instruction_memory logic_analyzer_alu_msb (
	.addra(addr_counter),         // a used for writing imem from reg interface
	.addrb(mem_addr_debug[11:0]),  // b used for gpu
	.clka(clk),
	.clkb(clk),
	.dina(exec_alu_out),
	.dinb(32'd0),
	.douta(),
	.doutb(alu_logic_analyzer[63:32]),
	.wea(start),
	.web(1'b0)
);
instruction_memory logic_analyzer_alu_lsb (
	.addra(addr_counter),         // a used for writing imem from reg interface
	.addrb(mem_addr_debug[11:0]),  // b used for gpu
	.clka(clk),
	.clkb(clk),
	.dina(exec_alu_out),
	.dinb(32'd0),
	.douta(),
	.doutb(alu_logic_analyzer[31:0]),
	.wea(start),
	.web(1'b0)
);

instruction_memory logic_analyzer_wbrd_l (
	.addra(addr_counter),         // a used for writing imem from reg interface
	.addrb(mem_addr_debug[11:0]),  // b used for gpu
	.clka(clk),
	.clkb(clk),
	.dina(wb_rd_data_mux_out[31:0]),
	.dinb(32'd0),
	.douta(),
	.doutb(wbrd_logic_analyzer[31:0]),
	.wea(start),
	.web(1'b0)
);

instruction_memory logic_analyzer_wbrd_m (
	.addra(addr_counter),         // a used for writing imem from reg interface
	.addrb(mem_addr_debug[11:0]),  // b used for gpu
	.clka(clk),
	.clkb(clk),
	.dina(wb_rd_data_mux_out[63:32]),
	.dinb(32'd0),
	.douta(),
	.doutb(wbrd_logic_analyzer[63:32]),
	.wea(start),
	.web(1'b0)
);


always@(posedge clk) begin
	if(reset) begin
 	 addr_counter <= 0;
	end
	if(start && (addr_counter<2000)) begin
	addr_counter <= addr_counter + 1;
	end
end

wire [4:0] rd_s;
wire [3:0] opcode;
wire eop;
wire predicated;
wire thread_batch_done;
wire [15:0] imm;
wire dtype;
wire rs1_type;
wire move_source;
wire rd_data_source;
wire move_source_thread_idx;
wire reg_we;



//////////////////////////
reg [3:0] if_id_lane_mask_reg;

reg [13:0] if_id_current_iteration_reg;

reg [4:0] id_ex_rd_s_out_reg;
reg [3:0] id_ex_opcode_reg;
reg id_ex_eop_reg;
reg id_ex_predicated_out_reg;
reg [15:0] id_ex_immediate_reg;
reg id_ex_dtype_reg;
reg id_ex_move_source_out_reg;
reg id_ex_imm_or_reg_source_out_reg;
reg id_ex_rd_data_source_out_reg;
reg id_ex_move_source_thread_idx_out;
reg id_ex_reg_write_enable;
reg [63:0] id_ex_rs3_s_reg;
reg [13:0] id_ex_if_id_current_iteration_reg;
reg id_ex_mem_we_reg;
reg id_ex_ret;

reg ex_mem_mem_write_enable;
reg [63:0] ex_mem_alu_out;
reg [3:0] ex_mem_opcode_reg;
reg [4:0] ex_mem_rd_s_out_reg;
reg ex_mem_rd_data_source_reg;
reg ex_mem_reg_write_enable;
reg ex_mem_ret;

reg [63:0] mem_wb_dmem_dout_reg;
reg [63:0] mem_wb_alu_out;
reg [3:0] mem_wb_opcode_reg;
reg [4:0] mem_wb_rd_s_out_reg;
reg mem_wb_rd_data_source_reg;
reg mem_wb_reg_write_enable;
/////////////////////////
wire mem_we;

wire tpu_parameter_write_en;
wire [2:0] tpu_parameter_type;

gpu_decoder_copy gpu_decode (
   .inst (instr),

   .rd_s_out (rd_s),
   .opcode_out (opcode),
   .eop_out (eop),
   .predicated_out (predicated),
   .thread_batch_done_out (thread_batch_done),
   .imm_out (imm),
   .dtype_out (dtype),
   .imm_or_reg_source_out (rs1_type),
   .move_source_out (move_source),
   .rd_data_source_out (rd_data_source),
   .move_source_thread_idx_out (move_source_thread_idx),
   .reg_write_enable (reg_we),
   .mem_write_enable(mem_we),
    // To regfile
   .rs1_s_out (rs1_s_id),
   .rs2_s_out (rs2_s_id),
   .rs3_s_out (rs3_s_id),
	.tpu_start (tpu_start),
	.tpu_parameter_write_en(tpu_parameter_write_en),
	.tpu_parameter_type(tpu_parameter_type)
);

wire [63:0] rs1_d, rs2_d, rs3_d;

registerunit2 gpu_regfile (
   .clk (clk),
   .rst (reset),

     // From decode unit
   .rs1_s (id_reg1_addr),
   .rs2_s (rs2_s_id),
   .rs3_s (rs3_s_id),

  
   .rd_s (mem_wb_rd_s_out_reg),
   .rd_d (wb_rd_data_mux_out),
   .we(mem_wb_reg_write_enable),
    // To pipeline registers
   .rs1_d (rs1_d),
   .rs2_d (rs2_d),
   .rs3_d (rs3_d)
 
);

wire [15:0] dmem_addr;

executionunit2 gpu_ex_unit (
   .clk (clk),
   .rst (reset),

   // From idex pipeline reg
   .opcode_in (id_ex_opcode_reg),
   .imm_in (id_ex_immediate_reg),
   .dtype_in (id_ex_dtype_reg),
   .rs1_type_in (id_ex_imm_or_reg_source_out_reg),
   .move_source_in (id_ex_move_source_out_reg),
   .rs1_d_in (id_ex_rs1_s_reg),
   .rs2_d_in (id_ex_rs2_s_reg),
  /// .fma_out(),
  // .fma_sig(),
	.rs3_d_in (id_ex_rs3_s_reg),
   .move_source_thread_idx_in (id_ex_move_source_thread_idx_out),
	.iteration_count(id_ex_if_id_current_iteration_reg),
	.lane_masks(id_ex_lane_mask_reg),
   // To exwb pipeline reg/dmem
   .rd_d_out (exec_alu_out),
   .dmem_addr (dmem_addr)   // For loads send read request from here
);

//wire [63:0] dmem_dout;
reg ex_mem1_ret, ex_mem2_ret, ex_mem3_ret, ex_mem4_ret;
reg ex_mem1_rd_data_source_reg, ex_mem2_rd_data_source_reg, ex_mem3_rd_data_source_reg, ex_mem4_rd_data_source_reg;
reg [4:0] ex_mem4_rd_s_out_reg, ex_mem3_rd_s_out_reg, ex_mem2_rd_s_out_reg, ex_mem1_rd_s_out_reg;
reg [3:0] ex_mem1_opcode_reg, ex_mem2_opcode_reg, ex_mem3_opcode_reg, ex_mem4_opcode_reg;
reg ex_mem1_reg_write_enable, ex_mem2_reg_write_enable, ex_mem3_reg_write_enable, ex_mem4_reg_write_enable;
//data_memory gpu_dmem(
//	.addra(dmem_addr[9:0]),             // Port A is for reading from EX
//	.addrb(mem_addr_debug[7:0]),    // Port B is for register interface
//	.clka(clk),
//	.clkb(clk),
//	.dina(ex_mem4_rs2_s_reg),
//	.dinb(mem_din_debug),
//	.douta(dmem_dout),
//	.doutb(dmem_dout_reg),
//	.wea(ex_mem4_we_reg),
//	.web(dmem_web) 
//);


reg id_ex_tpu_start,ex_mem1_tpu_start, ex_mem2_tpu_start, ex_mem3_tpu_start, ex_mem4_tpu_start, ex_mem_tpu_start, mem_wb_tpu_start;

				
assign wb_rd_data_mux_out = mem_wb_rd_data_source_reg ? mem_wb_dmem_dout_reg : mem_wb_alu_out;
reg [9:0] tpu_imm_addr;

always@(posedge clk)
	begin
		if(reset)
			begin
				if_id_lane_mask_reg <= 0;
				if_id_pc_out_reg <= 0;
				if_id_current_iteration_reg <= 0;
				
				id_ex_rd_s_out_reg <= 0;
				//id_ex_opcode_reg <= 0;
				id_ex_eop_reg <= 0;
				id_ex_predicated_out_reg <= 0;
				//id_ex_immediate_reg <= 0;
				id_ex_dtype_reg  <= 0;
				id_ex_move_source_out_reg <= 0;
				//id_ex_imm_or_reg_source_out_reg <= 0;
				//id_ex_rd_data_source_out_reg <= 0;
				id_ex_move_source_thread_idx_out <= 0;
				//id_ex_mem_write_enable <= 0;
				//id_ex_rs1_s_reg <= 0;
				//id_ex_rs2_s_reg <= 0;
				//id_ex_rs3_s_reg <= 0;
				//id_ex_if_id_current_iteration_reg <= 0;
				id_ex_lane_mask_reg <= 0;
				id_ex_mem_we_reg <= 0;
				
				ex_mem_mem_write_enable <= 0;
				//ex_mem_alu_out <= 0;
				ex_mem_opcode_reg <= 0;
				//ex_mem_rd_s_out_reg <= 0;
				ex_mem_rd_data_source_reg <= 0;
				
				//mem_wb_dmem_dout_reg <= 0;
				//mem_wb_alu_out <= 0;
				mem_wb_opcode_reg <= 0;
				//mem_wb_rd_s_out_reg <= 0;
				mem_wb_rd_data_source_reg <= 0;
				tpu_start_out <= 0;
				id_ex_tpu_start <= 0;
			//	ex_mem1_tpu_start <= 0;
			//	ex_mem2_tpu_start <= 0;
			//	ex_mem3_tpu_start <= 0;
			//	ex_mem4_tpu_start <= 0;
				//ex_mem_tpu_start <= 0;
				mem_wb_tpu_start <= 0;
				 w_addr_in <= 0;
				  i_addr_in <= 0;
				  bypass_add <= 0;
				  bypass_relu <= 0;
				  in_count <= 0;
				  w_count <= 0;
				  local_tpu_reset <= 0;
					tpu_imm_addr <= 0;
		
			end
		else
			begin
				if (start) begin
				if_id_lane_mask_reg <= lane_mask_out;
				if_id_pc_out_reg <= (tpu_start & ~tpu_done)? if_id_pc_out_reg : pc_out;
				
				if_id_current_iteration_reg <= current_iteration;
				
				id_ex_rd_s_out_reg <= rd_s;
				id_ex_opcode_reg <= opcode;
				id_ex_eop_reg <= eop;
				id_ex_predicated_out_reg <= predicated;
				id_ex_immediate_reg <= imm;
				id_ex_dtype_reg  <= dtype;
				id_ex_move_source_out_reg <= move_source;
				id_ex_imm_or_reg_source_out_reg <= rs1_type;
				id_ex_rd_data_source_out_reg <= rd_data_source;
				id_ex_move_source_thread_idx_out <= move_source_thread_idx;
				id_ex_reg_write_enable <= reg_we;
				id_ex_rs1_s_reg <= rs1_type ? {48'd0,imm} : rs1_d;
				id_ex_rs2_s_reg <= rs2_d;
				id_ex_rs3_s_reg <= rs3_d;
				id_ex_if_id_current_iteration_reg <= if_id_current_iteration_reg;
				id_ex_lane_mask_reg <= if_id_lane_mask_reg;
				id_ex_mem_we_reg <= mem_we;
				id_ex_ret <= thread_batch_done;
				
				ex_mem1_reg_write_enable <= id_ex_reg_write_enable;
				ex_mem2_reg_write_enable <= ex_mem1_reg_write_enable;
				ex_mem3_reg_write_enable <= ex_mem2_reg_write_enable;
				ex_mem4_reg_write_enable <= ex_mem3_reg_write_enable;
				ex_mem_reg_write_enable <= ex_mem4_reg_write_enable;
				
				ex_mem1_we_reg <= id_ex_mem_we_reg;
					ex_mem2_we_reg	<= ex_mem1_we_reg;
					ex_mem3_we_reg	<= ex_mem2_we_reg;
					ex_mem4_we_reg	<= ex_mem3_we_reg;
					//ex_mem_we_reg	<= ex_mem4_we_reg;

				ex_mem1_rs2_s_reg <= id_ex_rs2_s_reg;
				ex_mem2_rs2_s_reg <= ex_mem1_rs2_s_reg;
				ex_mem3_rs2_s_reg <= ex_mem2_rs2_s_reg;
				ex_mem4_rs2_s_reg <= ex_mem3_rs2_s_reg;
				ex_mem_alu_out <= exec_alu_out;
				ex_mem1_opcode_reg <= id_ex_opcode_reg;
				ex_mem2_opcode_reg <= ex_mem1_opcode_reg;
				ex_mem3_opcode_reg <= ex_mem2_opcode_reg;
				ex_mem4_opcode_reg <= ex_mem3_opcode_reg;
				ex_mem_opcode_reg <= ex_mem4_opcode_reg;

				ex_mem1_rd_s_out_reg <= id_ex_rd_s_out_reg;
				ex_mem2_rd_s_out_reg <= ex_mem1_rd_s_out_reg;
				ex_mem3_rd_s_out_reg <= ex_mem2_rd_s_out_reg;
				ex_mem4_rd_s_out_reg <= ex_mem3_rd_s_out_reg;
				ex_mem_rd_s_out_reg <= ex_mem4_rd_s_out_reg;
				
				ex_mem1_rd_data_source_reg <= id_ex_rd_data_source_out_reg;
				ex_mem2_rd_data_source_reg <= ex_mem1_rd_data_source_reg;
				ex_mem3_rd_data_source_reg <= ex_mem2_rd_data_source_reg;
				ex_mem4_rd_data_source_reg <= ex_mem3_rd_data_source_reg;
				ex_mem_rd_data_source_reg <= ex_mem4_rd_data_source_reg;
				
				ex_mem1_ret <= id_ex_ret;
				ex_mem2_ret <= ex_mem1_ret;
				ex_mem3_ret <= ex_mem2_ret;
				ex_mem4_ret <= ex_mem3_ret;
				ex_mem_ret <= ex_mem4_ret;
				
				mem_wb_dmem_dout_reg <= dmem_dout;
				mem_wb_alu_out <= ex_mem_alu_out;
				mem_wb_opcode_reg <= ex_mem_opcode_reg;
				mem_wb_rd_s_out_reg <= ex_mem_rd_s_out_reg;
				mem_wb_rd_data_source_reg <= ex_mem_rd_data_source_reg;
				mem_wb_reg_write_enable <= ex_mem_reg_write_enable;
				mem_wb_ret <= ex_mem_ret;
				
				id_ex_tpu_start <= tpu_start;
				ex_mem1_tpu_start <= id_ex_tpu_start;
				ex_mem2_tpu_start <= ex_mem1_tpu_start;
				ex_mem3_tpu_start <= ex_mem2_tpu_start;
				ex_mem4_tpu_start <= ex_mem3_tpu_start;
				ex_mem_tpu_start <= ex_mem4_tpu_start;
				mem_wb_tpu_start <= ex_mem_tpu_start;
					if(tpu_start == 1) tpu_start_out <= 1;
					else tpu_start_out <= 0;
						if(tpu_done == 1) begin
							tpu_imm_addr <= from_tpu_intermediate_address;
							tpu_start_out <= 0;
							local_tpu_reset <= 1;
							end
						else local_tpu_reset <= 0;
						
				if(tpu_parameter_write_en == 1'b1)
					begin
						case(tpu_parameter_type)
						3'd1: in_count <= instr[21:10];
						3'd2: w_count <= instr[21:10];
						3'd3: begin
									if(instr[31]) w_addr_in <= tpu_imm_addr + 1; 
									else w_addr_in <= instr[19:10];
						end
						3'd4: i_addr_in <= instr[19:10];
						3'd5: bypass_add <= instr[10];
						3'd6: bypass_relu <= instr[10];
						3'd0: first_hidden_layer <= instr[10];
						3'd7: final_layer <= instr[10];
						endcase
					end
				end
				
			end
	end
 
assign mem_addr = dmem_addr[9:0];
assign mem_din = ex_mem4_rs2_s_reg;
assign mem_we_out = ex_mem4_we_reg;
assign rs1_d_out = rs1_d; 

endmodule

