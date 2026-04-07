`timescale 1ns / 1ps

module GPU_CMT (
    input CLK, input RSTB, input gpu_begin,
    input [8:0] debug_pc, input debug_enable, input [31:0] debug_instr_in, input debug_instr_write_en, output [31:0] debug_instr_out,
	 output [7:0] mem_addr, output mem_we, output mem_en, output [63:0] mem_wr_data,input [63:0] mem_rd_data,
    output [8:0] PC_END,
	 output gpu_done
);

reg [8:0] PC_OUT; wire [31:0] instr_mem_douta;
wire w_RegDst, w_ALUSrc, w_MemtoReg, w_RegWrite, w_MemRead, w_MemWrite, w_Branch_ifEqual, w_Branch_ifNotEqual;
wire [3:0] w_ALU_Op_Out; wire w_IsFP, w_IsACCUM, w_Halt;
reg r_gpu_done;

reg ID_ALUSrc, ID_MemtoReg, ID_RegWrite, ID_MemRead, ID_MemWrite, ID_Branch_ifEqual, ID_Branch_ifNotEqual, ID_IsFP, ID_IsACCUM, ID_Halt;
reg [3:0] ID_ALUOp; reg [4:0] ID_Rs, ID_Rt, ID_Rd, ID_Ra; reg [15:0] ID_imm;
reg [31:0] ID_INSTR; reg [8:0] ID_PC_OUT; reg [63:0] reg_file [0:31];

wire [63:0] ID_XD_wire = (ID_Rs == 0) ? 64'd0 : reg_file[ID_Rs];
wire [63:0] ID_Yd_wire = (ID_Rt == 0) ? 64'd0 : reg_file[ID_Rt];
wire [63:0] ID_Zd_wire = (ID_Ra == 0) ? 64'd0 : reg_file[ID_Ra];

reg EX0_ALUSrc, EX0_MemtoReg, EX0_RegWrite, EX0_MemRead, EX0_MemWrite, EX0_Branch_ifEqual, EX0_Branch_ifNotEqual, EX0_IsFP, EX0_IsACCUM, EX0_Halt;
reg [3:0] EX0_ALUOp; reg [4:0] EX0_Rd; reg [15:0] EX0_imm; reg [63:0] EX0_XD, EX0_Yd, EX0_Zd;
reg [31:0] EX0_INSTR; reg [8:0] EX0_PC_OUT;
wire [63:0] EX0_imm_extended;
wire [63:0] EX0_operand_A = EX0_XD;
wire [63:0] EX0_operand_B = EX0_ALUSrc ? EX0_imm_extended : EX0_Yd;
wire [63:0] EX0_ACC_in    = EX0_Zd;

// UPDATED EX1 REGISTERS FOR PIPELINED MULTIPLIER
reg EX1_MemtoReg, EX1_RegWrite, EX1_MemRead, EX1_MemWrite, EX1_IsFP;
reg [3:0] EX1_ALUOp; reg [4:0] EX1_Rd;
reg [63:0] EX1_ALU_OUT, EX1_STORE_DATA, EX1_operand_A, EX1_operand_B, EX1_ACC_in;
reg [3:0]  EX1_sign_mult; 
reg [31:0] EX1_final_exp_mult; 
reg [27:0] EX1_final_sig_mult; 
reg [63:0] EX1_mult_out; 

reg EX2_MemtoReg, EX2_RegWrite, EX2_MemRead, EX2_MemWrite, EX2_IsFP;
reg [3:0] EX2_ALUOp; reg [4:0] EX2_Rd;
reg [63:0] EX2_ALU_OUT, EX2_STORE_DATA, EX2_mult_out, EX2_operand_A;
reg [31:0] EX2_sig_large, EX2_sig_aligned, EX2_exp_large;
reg [3:0] EX2_sign_final, EX2_do_sub;

wire [63:0] data_mem_douta;
reg MEM_MemtoReg, MEM_RegWrite, MEM_MemRead, MEM_MemWrite, MEM_IsFP;
reg [4:0] MEM_Rd; reg [63:0] MEM_ALU_OUT, MEM_STORE_DATA, MEM_FP_OUT;

reg WB_MemtoReg, WB_RegWrite, WB_IsFP;
reg [4:0] WB_Rd; reg [63:0] WB_ALU_OUT, WB_FP_OUT; wire [63:0] WB_RData;


// =========================================================================
// DATAPATH LOGIC
// =========================================================================
instr_mem_dp_GPU ICache (.addra(PC_OUT), .clka(CLK), .douta(instr_mem_douta), .ena(1'b1), .clkb(CLK), .addrb(debug_pc[8:0]), .dinb(debug_instr_in[31:0]), .doutb(debug_instr_out[31:0]), .enb(debug_enable), .web(debug_instr_write_en));
control_unit_GPU main_control (.opcode(instr_mem_douta[31:26]), .RegDst(w_RegDst), .ALUSrc(w_ALUSrc), .MemtoReg(w_MemtoReg), .RegWrite(w_RegWrite), .MemRead(w_MemRead), .MemWrite(w_MemWrite), .Beq(w_Branch_ifEqual), .Bne(w_Branch_ifNotEqual), .ALUOp1(), .ALUOp0(), .ALU_Op_Out(w_ALU_Op_Out), .IsFP(w_IsFP), .IsACCUM(w_IsACCUM), .Halt(w_Halt));
sign_extend_GPU sign_ext (.in(EX0_imm), .out(EX0_imm_extended));
assign PC_END = PC_OUT;
assign gpu_done = r_gpu_done;

// EX0
wire [63:0] w_alu_result; wire w_alu_zero;
alu_64_GPU theALU (.A(EX0_operand_A), .ALUOp(EX0_ALUOp), .B(EX0_operand_B), .O(w_alu_result), .N(), .V(), .C(), .Z(w_alu_zero));
wire Br1 = (EX0_Branch_ifEqual && w_alu_zero) || (EX0_Branch_ifNotEqual && !w_alu_zero);
wire [8:0] BTA = EX0_PC_OUT + EX0_imm_extended[8:0];

wire [63:0] fp_op_A = EX0_IsFP ? EX0_operand_A : 64'b0;
wire [63:0] fp_op_B = EX0_IsFP ? EX0_operand_B : 64'b0;

wire [3:0]  w_ex0_sign_mult; 
wire [31:0] w_ex0_final_exp; 
wire [27:0] w_ex0_final_sig;
wire [63:0] w_ex0_mult_out;
// EX0
bfloat16_simd64_ex0_prep fp_prep (
    .reg_a(fp_op_A), .reg_b(fp_op_B), 
    .sign_mult(w_ex0_sign_mult), .final_exp_mult(w_ex0_final_exp), .final_sig_mult(w_ex0_final_sig), .mult_out(w_ex0_mult_out)
);

// EX1
wire [31:0] w_ex1_sig_large, w_ex1_sig_aligned, w_ex1_exp_large;
wire [3:0]  w_ex1_sign_final, w_ex1_do_sub; 
wire is_mac_inst = (EX1_ALUOp == 4'b0111);
wire [63:0] ex1_fp_op_b = is_mac_inst ? EX1_ACC_in : EX1_operand_B;

bfloat16_simd64_ex1_align fp_align (
    .sign_mult_in(EX1_sign_mult), .final_exp_mult(EX1_final_exp_mult), .final_sig_mult(EX1_final_sig_mult),
    .add_op_a(EX1_operand_A), .add_op_b(ex1_fp_op_b), .is_mac(is_mac_inst), 
    .sig_large(w_ex1_sig_large), .sig_aligned(w_ex1_sig_aligned), .exp_large(w_ex1_exp_large), .sign_final(w_ex1_sign_final), .do_sub(w_ex1_do_sub)
);

// EX2
wire [63:0] w_simd_bfloat_add_out;
bfloat16_simd64_ex2_norm fp_norm (
    .sig_large(EX2_sig_large), .sig_aligned(EX2_sig_aligned), .exp_large(EX2_exp_large), 
    .sign_final(EX2_sign_final), .do_sub(EX2_do_sub), .final_out(w_simd_bfloat_add_out)
);

wire [63:0] w_relu_result;
assign w_relu_result[63:48] = EX2_operand_A[63] ? 16'h0000 : EX2_operand_A[63:48];
assign w_relu_result[47:32] = EX2_operand_A[47] ? 16'h0000 : EX2_operand_A[47:32];
assign w_relu_result[31:16] = EX2_operand_A[31] ? 16'h0000 : EX2_operand_A[31:16];
assign w_relu_result[15:0]  = EX2_operand_A[15] ? 16'h0000 : EX2_operand_A[15:0];

reg [63:0] r_ex2_fp_out;
always @(*) begin
    case (EX2_ALUOp)
        4'b0100, 4'b0111: r_ex2_fp_out = w_simd_bfloat_add_out; // ADD_FP or MAC
        4'b0101:          r_ex2_fp_out = EX2_mult_out;          // MULT_FP
        4'b0110:          r_ex2_fp_out = w_relu_result;         // ReLU
        default:          r_ex2_fp_out = EX2_ALU_OUT;           // Integer Fallback
    endcase
end

// =============================
// Data Memory Interface
// =============================

assign mem_we = MEM_MemWrite;
assign mem_en = MEM_MemRead | MEM_MemWrite;
assign mem_addr = MEM_ALU_OUT[7:0];
assign mem_wr_data = MEM_STORE_DATA;
assign data_mem_douta = mem_rd_data;



// MEM & WB
/*data_mem_64_256 DCache (.addra(MEM_ALU_OUT[7:0]), 
.clka(CLK), 
.dina(MEM_STORE_DATA), 
.douta(data_mem_douta), 
.ena(MEM_MemRead | MEM_MemWrite), 
.wea(MEM_MemWrite), 
.clkb(CLK), 
.addrb(debug_addr_in[7:0]), 
.dinb(debug_data_in[63:0]), 
.enb(debug_enable), 
.web(debug_data_write_en), 
.doutb(debug_data_out[63:0]));*/

assign WB_RData = WB_MemtoReg ? data_mem_douta : (WB_IsFP ? WB_FP_OUT : WB_ALU_OUT);
assign stall = (w_Halt && !gpu_begin) || r_gpu_done;

// =========================================================================
// SEQUENTIAL PIPELINE LOGIC 
// =========================================================================
always @(posedge CLK or negedge RSTB) begin
    if (!RSTB) begin
        PC_OUT <= 0;
        ID_Rs <= 0; ID_Rt <= 0; ID_Rd <= 0; ID_Ra <= 0; ID_imm <= 0; ID_INSTR <= 0; ID_PC_OUT <= 0;
        ID_ALUSrc <= 0; ID_MemtoReg <= 0; ID_RegWrite <= 0; ID_MemRead <= 0; ID_MemWrite <= 0; ID_Branch_ifEqual <= 0; ID_Branch_ifNotEqual <= 0; ID_ALUOp <= 0; ID_IsFP <= 0; ID_IsACCUM <= 0; ID_Halt <= 0;
        
        EX0_XD <= 0; EX0_Yd <= 0; EX0_Zd <= 0; EX0_imm <= 0; EX0_Rd <= 0; EX0_INSTR <= 0; EX0_PC_OUT <= 0;
        EX0_ALUSrc <= 0; EX0_MemtoReg <= 0; EX0_RegWrite <= 0; EX0_MemRead <= 0; EX0_MemWrite <= 0; EX0_Branch_ifEqual <= 0; EX0_Branch_ifNotEqual <= 0; EX0_ALUOp <= 0; EX0_IsFP <= 0; EX0_IsACCUM <= 0; EX0_Halt <= 0;
        
        EX1_ALU_OUT <= 0; EX1_operand_A <= 0; EX1_operand_B <= 0; EX1_ACC_in <= 0; EX1_STORE_DATA <= 0; EX1_Rd <= 0;
        EX1_MemtoReg <= 0; EX1_RegWrite <= 0; EX1_MemRead <= 0; EX1_MemWrite <= 0; EX1_IsFP <= 0; EX1_ALUOp <= 0;
        EX1_sign_mult <= 0; EX1_final_exp_mult <= 0; EX1_final_sig_mult <= 0; EX1_mult_out <= 0;
        
        EX2_ALU_OUT <= 0; EX2_STORE_DATA <= 0; EX2_mult_out <= 0; EX2_operand_A <= 0; EX2_Rd <= 0;
        EX2_MemtoReg <= 0; EX2_RegWrite <= 0; EX2_MemRead <= 0; EX2_MemWrite <= 0; EX2_IsFP <= 0; EX2_ALUOp <= 0;
        EX2_sig_large <= 0; EX2_sig_aligned <= 0; EX2_exp_large <= 0; EX2_sign_final <= 0; EX2_do_sub <= 0;
        
        MEM_ALU_OUT <= 0; MEM_STORE_DATA <= 0; MEM_FP_OUT <= 0; MEM_Rd <= 0;
        MEM_MemtoReg <= 0; MEM_RegWrite <= 0; MEM_MemRead <= 0; MEM_MemWrite <= 0; MEM_IsFP <= 0;
        
        WB_ALU_OUT <= 0; WB_FP_OUT <= 0; WB_Rd <= 0;
        WB_MemtoReg <= 0; WB_RegWrite <= 0; WB_IsFP <= 0;
    end 
    else begin
        if (WB_RegWrite && (WB_Rd != 0)) reg_file[WB_Rd] <= WB_RData;

        if (gpu_begin) begin
				PC_OUT <= 3;
				r_gpu_done <= 0;
		  end
		  else if (Br1) PC_OUT <= BTA; //Branch Target address // get out of HALT loop
		  
		  else if (stall) begin //PC_OUT <= PC_OUT - 2; //keep executing halt instruction
				EX0_XD <= 0; EX0_Yd <= 0; EX0_Zd <= 0; EX0_imm <= 0; EX0_Rd <= 0; EX0_INSTR <= 0; EX0_PC_OUT <= 0;
				EX0_ALUSrc <= 0; EX0_MemtoReg <= 0; EX0_RegWrite <= 0; EX0_MemRead <= 0; EX0_MemWrite <= 0; EX0_Branch_ifEqual <= 0; EX0_Branch_ifNotEqual <= 0; EX0_ALUOp <= 0; EX0_IsFP <= 0; EX0_IsACCUM <= 0; EX0_Halt <= 0;
        
			   EX1_ALU_OUT <= 0; EX1_operand_A <= 0; EX1_operand_B <= 0; EX1_ACC_in <= 0; EX1_STORE_DATA <= 0; EX1_Rd <= 0;
			   EX1_MemtoReg <= 0; EX1_RegWrite <= 0; EX1_MemRead <= 0; EX1_MemWrite <= 0; EX1_IsFP <= 0; EX1_ALUOp <= 0;
			   EX1_sign_mult <= 0; EX1_final_exp_mult <= 0; EX1_final_sig_mult <= 0; EX1_mult_out <= 0;
			  
			   EX2_ALU_OUT <= 0; EX2_STORE_DATA <= 0; EX2_mult_out <= 0; EX2_operand_A <= 0; EX2_Rd <= 0;
			   EX2_MemtoReg <= 0; EX2_RegWrite <= 0; EX2_MemRead <= 0; EX2_MemWrite <= 0; EX2_IsFP <= 0; EX2_ALUOp <= 0;
			   EX2_sig_large <= 0; EX2_sig_aligned <= 0; EX2_exp_large <= 0; EX2_sign_final <= 0; EX2_do_sub <= 0;
			  
			   MEM_ALU_OUT <= 0; MEM_STORE_DATA <= 0; MEM_FP_OUT <= 0; MEM_Rd <= 0;
			   MEM_MemtoReg <= 0; MEM_RegWrite <= 0; MEM_MemRead <= 0; MEM_MemWrite <= 0; MEM_IsFP <= 0;
			  
			   WB_ALU_OUT <= 0; WB_FP_OUT <= 0; WB_Rd <= 0;
			   WB_MemtoReg <= 0; WB_RegWrite <= 0; WB_IsFP <= 0; 
				r_gpu_done <= 1;
		  end 
        
		  else     PC_OUT <= PC_OUT + 1; // keep executing INS

        ID_Rs <= instr_mem_douta[25:21]; ID_Rt <= instr_mem_douta[20:16]; ID_Rd <= w_RegDst ? instr_mem_douta[15:11] : instr_mem_douta[20:16]; ID_Ra <= instr_mem_douta[10:6]; ID_imm <= instr_mem_douta[15:0];
        ID_ALUSrc <= w_ALUSrc; ID_MemtoReg <= w_MemtoReg; ID_RegWrite <= w_RegWrite; ID_MemRead <= w_MemRead; ID_MemWrite <= w_MemWrite; ID_Branch_ifEqual <= w_Branch_ifEqual; ID_Branch_ifNotEqual <= w_Branch_ifNotEqual; ID_ALUOp <= w_ALU_Op_Out; ID_INSTR <= instr_mem_douta; ID_IsFP <= w_IsFP; ID_IsACCUM <= w_IsACCUM; ID_PC_OUT <= PC_OUT;

        EX0_XD <= ID_XD_wire; EX0_Yd <= ID_Yd_wire; EX0_Zd <= ID_Zd_wire; EX0_imm <= ID_imm; EX0_Rd <= ID_Rd;
        EX0_ALUSrc <= ID_ALUSrc; EX0_MemtoReg <= ID_MemtoReg; EX0_RegWrite <= ID_RegWrite; EX0_MemRead <= ID_MemRead; EX0_MemWrite <= ID_MemWrite; EX0_Branch_ifEqual <= ID_Branch_ifEqual; EX0_Branch_ifNotEqual <= ID_Branch_ifNotEqual; EX0_ALUOp <= ID_ALUOp; EX0_INSTR <= ID_INSTR; EX0_IsFP <= ID_IsFP; EX0_IsACCUM <= ID_IsACCUM; EX0_Halt <= w_Halt; EX0_PC_OUT <= ID_PC_OUT;

        EX1_ALU_OUT <= w_alu_result; EX1_operand_A <= EX0_operand_A; EX1_operand_B <= EX0_operand_B; EX1_ACC_in <= EX0_ACC_in; EX1_STORE_DATA <= EX0_Yd; EX1_Rd <= EX0_Rd;
        
        EX1_sign_mult <= w_ex0_sign_mult; EX1_final_exp_mult <= w_ex0_final_exp; EX1_final_sig_mult <= w_ex0_final_sig; EX1_mult_out <= w_ex0_mult_out;
        
        EX1_MemtoReg <= EX0_MemtoReg; EX1_RegWrite <= EX0_RegWrite; EX1_MemRead <= EX0_MemRead; EX1_MemWrite <= EX0_MemWrite; EX1_IsFP <= EX0_IsFP; EX1_ALUOp <= EX0_ALUOp;

        EX2_ALU_OUT <= EX1_ALU_OUT; EX2_STORE_DATA <= EX1_STORE_DATA; EX2_Rd <= EX1_Rd;
        EX2_sig_large <= w_ex1_sig_large; EX2_sig_aligned <= w_ex1_sig_aligned; EX2_exp_large <= w_ex1_exp_large; EX2_sign_final <= w_ex1_sign_final; EX2_do_sub <= w_ex1_do_sub;
        
        EX2_mult_out <= EX1_mult_out; EX2_operand_A <= EX1_operand_A; 
        
        EX2_MemtoReg <= EX1_MemtoReg; EX2_RegWrite <= EX1_RegWrite; EX2_MemRead <= EX1_MemRead; EX2_MemWrite <= EX1_MemWrite; EX2_IsFP <= EX1_IsFP; EX2_ALUOp <= EX1_ALUOp;

        MEM_ALU_OUT <= EX2_ALU_OUT; MEM_STORE_DATA <= EX2_STORE_DATA; MEM_FP_OUT <= r_ex2_fp_out; MEM_Rd <= EX2_Rd;
        MEM_MemtoReg <= EX2_MemtoReg; MEM_RegWrite <= EX2_RegWrite; MEM_MemRead <= EX2_MemRead; MEM_MemWrite <= EX2_MemWrite; MEM_IsFP <= EX2_IsFP;

        WB_ALU_OUT <= MEM_ALU_OUT; WB_FP_OUT <= MEM_FP_OUT; WB_Rd <= MEM_Rd;
        WB_MemtoReg <= MEM_MemtoReg; WB_RegWrite <= MEM_RegWrite; WB_IsFP <= MEM_IsFP;
    end
end
endmodule