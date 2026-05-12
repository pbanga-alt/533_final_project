`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    04:52:32 02/28/2026 
// Design Name: 
// Module Name:    executionunit2 
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
// Global params
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
`define MUL	4'd9
`define RELU	4'd10

module executionunit2(								input clk,
								input rst,

   // From idex pipeline reg
								input [3:0] opcode_in,
								input [15:0] imm_in,
								input dtype_in,
								input rs1_type_in,
								input move_source_in,
								input [63:0] rs1_d_in,
								input [63:0] rs2_d_in,
								input [63:0] rs3_d_in, 
								input move_source_thread_idx_in,
								input [13:0] iteration_count,
								input [3:0] lane_masks,
    // To exwb pipeline reg/dmem
								output [63:0] rd_d_out,
								output [15:0] dmem_addr    
								// For loads send read request from here
							);

// ---------- Local Variables ---------- //
reg  [63:0]        rd_d;
//reg [63:0] rd_d_out_reg;
reg [15:0] dmem_addr_reg;
reg  [2:0]         func;   // 0 = add, 1 = sub, 2 = greater/equal, 3 = max
wire  [15:0]        alu_out_0, alu_out_1, alu_out_2, alu_out_3;
wire [15:0] alu_pre_mask_0, alu_pre_mask_1, alu_pre_mask_2, alu_pre_mask_3;
//wire  [15:0]        dmem_addr;


//reg [15:0] dmem_s1, dmem_s2, dmem_s3, dmem_s4;

assign rd_d_out = rd_d;
assign dmem_addr = dmem_addr_reg;

reg [63:0] r1_s1,r1_s2,r1_s3,r1_s4,r2_s1,r2_s2,r2_s3,r2_s4;
reg [15:0] imm_s1,imm_s2,imm_s3,imm_s4;
reg [13:0] itr_count_s1,itr_count_s2,itr_count_s3,itr_count_s4; 
reg [3:0] op_s1, op_s2, op_s3, op_s4;
reg [3:0] lm_s1, lm_s2, lm_s3, lm_s4;
reg msti_s1, msti_s2, msti_s3, msti_s4;
reg msi_s1, msi_s2, msi_s3, msi_s4;
reg din_s1, din_s2, din_s3, din_s4;
always @(posedge clk) begin
	lm_s1 <= lane_masks;
	lm_s2 <= lm_s1;
	lm_s3 <= lm_s2;
	lm_s4 <= lm_s3;
	din_s1 <= dtype_in;
	din_s2 <= din_s1;
	din_s3 <= din_s2;
	din_s4 <= din_s3;
	msi_s1 <= move_source_in;
	msi_s2 <= msi_s1;
	msi_s3 <= msi_s2;
	msi_s4 <= msi_s3;
	msti_s1 <= move_source_thread_idx_in;
	msti_s2 <= msti_s1;
	msti_s3 <= msti_s2;
	msti_s4 <= msti_s3;
	op_s1 <= opcode_in;
	op_s2 <= op_s1;
	op_s3 <= op_s2;
	op_s4 <= op_s3;
//	dmem_s1 <= dmem_addr_reg;
//	dmem_s2 <= dmem_s1;
//	dmem_s3 <= dmem_s2;
//	dmem_s4 <= dmem_s3;
	itr_count_s1 <= iteration_count;
	itr_count_s2 <= itr_count_s1;
	itr_count_s3 <= itr_count_s2;
	itr_count_s4 <= itr_count_s3;
	imm_s1 <= imm_in;
	imm_s2 <= imm_s1;
	imm_s3 <= imm_s2;
	imm_s4 <= imm_s3;
	r1_s1 <= rs1_d_in;
	r1_s2 <= r1_s1;
	r1_s3 <= r1_s2;
	r1_s4 <= r1_s3;
	r2_s1 <= rs2_d_in;
	r2_s2 <= r2_s1;
	r2_s3 <= r2_s2;
	r2_s4 <= r2_s3;
end 

always@(*) begin
	case(opcode_in) 
	`SETP: func = 010;
	`ADD: func = 000;
	`SUB: func = 001;
	`MUL: func = 100;
	`FMA: func = 110;
	`RELU: func = 101;
	`MAX: func = 011;
	default: func = 000;
	endcase
end
// ---------- Execution Logic ---------- //
mini_alu t0_alu(.clk(clk),.rst(rst),
    .func (func),
    .a (rs1_d_in[15:0]),
    .b (rs2_d_in[15:0]),
	 .c (rs3_d_in[15:0]),
    .out (alu_pre_mask_0)
);

mini_alu t1_alu(.clk(clk),.rst(rst),
    .func (func),
    .a (rs1_d_in[31:16]),
    .b (rs2_d_in[31:16]),
 	 .c (rs3_d_in[31:16]),
	 .out (alu_pre_mask_1)
);

mini_alu t2_alu(.clk(clk),.rst(rst),
    .func (func),
    .a (rs1_d_in[47:32]),
    .b (rs2_d_in[47:32]),
	 .c (rs3_d_in[47:32]),
    .out (alu_pre_mask_2)
);

 mini_alu t3_alu(.clk(clk),.rst(rst),
    .func (func),
    .a (rs1_d_in[63:48]),
    .b (rs2_d_in[63:48]),
 	 .c (rs3_d_in[63:48]),
	 .out (alu_pre_mask_3)
);

assign alu_out_0 = alu_pre_mask_0 & {16{lm_s4[0]}};
assign alu_out_1 = alu_pre_mask_1 & {16{lm_s4[1]}};
assign alu_out_2 = alu_pre_mask_2 & {16{lm_s4[2]}};
assign alu_out_3 = alu_pre_mask_3 & {16{lm_s4[3]}};


always@(*) begin
    rd_d = 64'd00;
    dmem_addr_reg = 16'd0;

    case (op_s4)
        `LOAD : begin
            dmem_addr_reg = r1_s4[15:0];
          //  rd_d = {rs1_d_in[15:0], rs1_d_in[15:0], rs1_d_in[15:0], rs1_d_in[15:0]}; // If loading from param reg, param data will be passed into rs1_d pipeline reg in top level
        end

        `STORE : begin
            dmem_addr_reg = r1_s4[15:0];
        end

        `MOVE : begin
            if (msi_s4) begin
                rd_d[15:0] = imm_s4;
            end else if (msti_s4) begin
                rd_d[13:0] = itr_count_s4;
					 //rd_d[29:16] = iteration_count;
					 //rd_d[45:32] = iteration_count;
					 //rd_d[61:48] = iteration_count;
                //rd_d[29:16] = iteration_count + 2'b01;
                //rd_d[45:32] = iteration_count + 2'b10;
                //rd_d[61:48] = iteration_count + 2'b11;
            end else begin
                rd_d = r1_s4;
            end
        end

        `SETP : begin
            rd_d[0] = alu_out_0[0];
            rd_d[16] = alu_out_1[0];
            rd_d[32] = alu_out_2[0];
            rd_d[48] = alu_out_3[0];
            //func = 3'b010;
        end

        `ADD : begin
            rd_d = {alu_out_3, alu_out_2, alu_out_1, alu_out_0};
          //  func = 3'b000;
				if(din_s4) rd_d = {48'd0,r1_s4[15:0] + r2_s4[15:0]};
        end

        `SUB : begin
            rd_d = {alu_out_3, alu_out_2, alu_out_1, alu_out_0};
        //    func = 2'b001;
        end
			`MUL : begin
            rd_d = {alu_out_3, alu_out_2, alu_out_1, alu_out_0};
        //    func = 3'b100;
        end
		  `FMA : begin
          rd_d = {alu_out_3, alu_out_2, alu_out_1, alu_out_0};
        //  func = 3'b110;
        end
		  `RELU : begin
          rd_d = {alu_out_3, alu_out_2, alu_out_1, alu_out_0};
       //   func = 3'b101;
        end
        `MAX : begin
            rd_d = {alu_out_3, alu_out_2, alu_out_1, alu_out_0};
         //   func = 3'b011;
        end

        default : begin // Dont need to do anything for RET, handle FMA in tensor unit?

        end

    endcase

end
endmodule
