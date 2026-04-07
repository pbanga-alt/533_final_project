`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    17:19:52 03/22/2026 
// Design Name: 
// Module Name:    gpu_decoder_copy 
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


// Opcodes
`define RET    4'd0
`define LOAD   4'd1
`define STORE  4'd2
`define MOVE   4'd3
`define SETP   4'd4
`define ADD    4'd5
`define SUB    4'd6
`define FMA    4'd7
`define MAX    4'd8
`define MUL		4'd9
`define RELU	4'd10
`define TPU 4'd11
`define TPU_PARAMETER 4'd12

module gpu_decoder_copy(


  //  input clk,
  //  input rst,

    // From imem
    input [31:0] inst,

    // To idex pipeline reg
    output [4:0] rd_s_out,
    output [3:0] opcode_out,
    output eop_out,
    output predicated_out,
    output thread_batch_done_out,
    output [15:0] imm_out,
    output dtype_out,
    output imm_or_reg_source_out,
    output move_source_out,
    output rd_data_source_out,
    output move_source_thread_idx_out,
    output reg_write_enable,
	 output mem_write_enable,

    // To regfile
    output [4:0] rs1_s_out,
    output [4:0] rs2_s_out,
    output [4:0] rs3_s_out,
	 output tpu_start,
	 output tpu_parameter_write_en,
	 output [2:0] tpu_parameter_type
);

// ---------- Local Parameters ---------- //


// ---------- Local Variables ---------- //
wire [3:0] opcode;
reg [4:0] rd_s, rs1_s, rs2_s, rs3_s;
wire [15:0] imm;
wire eop, predicated, dtype;

reg thread_batch_done;
reg imm_or_reg_source;  // 0 = regular regs, 1 = immediate value
reg move_source;   // 0 = register, 1 = immediate
reg rd_data_source;    // 0 = ex unit/tensor unit, 1 = memory
reg move_source_thread_idx;    // 0 = no, 1 = yes move source is %tid.x
reg reg_we;
reg mem_write_reg;
// these dont change based off inst so just assign
assign opcode = inst[3:0];
assign imm = inst[25:10];
assign eop = inst[31];
assign predicated = inst[30];
assign dtype = inst[29];
reg tpu_out;

assign tpu_start = tpu_out;
reg tpu_parameter_write_en_reg;
reg [2:0] tpu_parameter_type_reg;

assign tpu_parameter_write_en = tpu_parameter_write_en_reg;
assign tpu_parameter_type = tpu_parameter_type_reg;

// ---------- Decode Logic ---------- //

always @(*) begin
    rd_s = 5'd0;
    rs1_s = 5'd0;
    rs2_s = 5'd0;
    rs3_s = 5'd0;
    thread_batch_done = 1'b0;
    imm_or_reg_source = 1'b0;
    move_source = 1'b0;
    rd_data_source = 1'b0;
    move_source_thread_idx = 1'b0;
    reg_we = 1'b0;
	mem_write_reg = 1'b0;
	tpu_out = 1'b0;
	tpu_parameter_write_en_reg = 0 ;
	tpu_parameter_type_reg = 3'd0;
    case (opcode)
        `RET : begin
			if (eop)   thread_batch_done = 1'b1;
        end

        `LOAD : begin
            rd_s = inst[9:5];
            rs1_s = inst[14:10];
            imm_or_reg_source = inst[4];
            rd_data_source = 1'b1;
            reg_we = 1'b1;
        end

        `STORE : begin
            rs2_s = inst[9:5];
            rs1_s = inst[14:10];
				mem_write_reg = 1'b1;
            imm_or_reg_source = 1'b0;    // cannot store to param regs read only
        end

        `MOVE : begin
            rd_s = inst[9:5];
            move_source = inst[4];
            rs1_s = (move_source) ? 5'd0 : inst[14:10];
            move_source_thread_idx = (rs1_s == 5'b11111);
            rd_data_source = 1'b0;
            reg_we = 1'b1;
        end

        `SETP : begin
            rs1_s = inst[8:4];
            rs2_s = inst[13:9];
            rd_data_source = 1'b0;
            reg_we = 1'b1;
        end

        `ADD : begin
            rd_s = inst[8:4];
            rs1_s = inst[13:9];
            rs2_s = inst[18:14];
            rd_data_source = 1'b0;
            reg_we = 1'b1;
        end
		  `MUL : begin
            rd_s = inst[8:4];
            rs1_s = inst[13:9];
            rs2_s = inst[18:14];
            rd_data_source = 1'b0;
            reg_we = 1'b1;
			end
			`RELU : begin
            rd_s = inst[8:4];
            rs1_s = inst[13:9];
            rd_data_source = 1'b0;
            reg_we = 1'b1;
        end
        `SUB : begin
            rd_s = inst[8:4];
            rs1_s = inst[13:9];
            rs2_s = inst[18:14];
            rd_data_source = 1'b0;
            reg_we = 1'b1;
        end

        `FMA : begin
            rd_s = inst[8:4];
            rs1_s = inst[13:9];
            rs2_s = inst[18:14];
            rs3_s = inst[24:19];
            rd_data_source = 1'b0;
            reg_we = 1'b1;
        end

        `MAX : begin
            rd_s = inst[8:4];
            rs1_s = inst[13:9];
            rs2_s = inst[18:14];
            rd_data_source = 1'b0;
            reg_we = 1'b1;
        end
		  `TPU: begin
					tpu_out = 1'b1;
				 end
			`TPU_PARAMETER: begin
					tpu_parameter_write_en_reg = 1;
					tpu_parameter_type_reg = inst[9:4];
					//0 - number of hidden layers
					//1 - in_count
					//2 - w_count
					//3 - w_addr_in
					//4 - in_addr_in
					//5 - bypass_adder
					//6 - bypass_relu
					//7 - ANN or not?
				end
		  

        default : begin
            //thread_batch_done = 1'b1;
        end
    endcase
end

assign rd_s_out = rd_s;
assign opcode_out = opcode;
assign eop_out = eop;
assign predicated_out = predicated;
assign thread_batch_done_out = thread_batch_done;
assign imm_out = imm;
assign dtype_out = dtype;
assign imm_or_reg_source_out = imm_or_reg_source;
assign move_source_out = move_source;
assign rd_data_source_out = rd_data_source;
assign move_source_thread_idx_out = move_source_thread_idx;
assign reg_write_enable = reg_we;
assign mem_write_enable = mem_write_reg;
assign rs1_s_out = rs1_s;
assign rs2_s_out = rs2_s;
assign rs3_s_out = rs3_s;


endmodule
