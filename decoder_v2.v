`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////

module decoder_dpu_v1( 
				input[31:0] instr,
				output reg [3:0] aluctrl,
				output reg alusrc_A,
				output reg branch,
				output reg regwrite,
				output reg dmemwrite,
				output reg jump,
				output reg memtoreg,
				output reg noop,	
				output alusrc_B,				
				output[3:0] passcond,
				output update_flags,
				output gpu_out			 
    );

/*
Instruction format
opcode = instr[4:0]
cond = instr[8:5]
register source or immediate field = instr[9]
Source register 1 = instr[12:10]
Source register 2 = instr[15:13]
Destination register = instr[18:16]
Immediate number/offset field = [27:19]
Not used = instr[28]
Update flags = instr[29]
User_stall = instr[30]
LA_Trigger = instr[31]
*/
reg gpu_reg;
assign alusrc_B 		= 		instr[9];
assign passcond 		= 		instr[8:5];
assign update_flags 	= 		instr[29];	

always@(*)
	begin
		aluctrl 		= 		4'b0000;
		alusrc_A		=		1'b0;
		branch			=		1'b0;
		regwrite		=		1'b0;
		dmemwrite		=		1'b0;
		jump			=		1'b0;
		memtoreg		=		1'b0;
		noop			=		1'b1;

		case(instr[4:0])
			5'd1: //ldr
				begin
					aluctrl 		= 		4'b0000;
					alusrc_A		=		1'b0;
					branch			=		1'b0;
					regwrite		=		1'b1;
					dmemwrite		=		1'b0;
					jump			=		1'b0;
					memtoreg		=		1'b1;
					noop			=		1'b0;
					gpu_reg  = 1'b0;		
				end
			5'd2: //str
				begin
					aluctrl 		= 		4'b0000;
					alusrc_A		=		1'b0;
					branch			=		1'b0;
					regwrite		=		1'b0;
					dmemwrite		=		1'b1;
					jump			=		1'b0;
					memtoreg		=		1'b0;
					noop			=		1'b0;
					gpu_reg  = 1'b0;		
				end
			5'd3: //add
				begin
					aluctrl 		= 		4'b0000;
					alusrc_A		=		1'b0;
					branch			=		1'b0;
					regwrite		=		1'b1;
					dmemwrite		=		1'b0;
					jump			=		1'b0;
					memtoreg		=		1'b0;
					noop			=		1'b0;
					gpu_reg  = 1'b0;		
				end
			5'd4: //sub
				begin
					aluctrl 		= 		4'b0001;
					alusrc_A		=		1'b0;
					branch			=		1'b0;
					regwrite		=		1'b1;
					dmemwrite		=		1'b0;
					jump			=		1'b0;
					memtoreg		=		1'b0;
					noop			=		1'b0;					
					gpu_reg  = 1'b0;		
				end
			5'd5: //and
				begin
					aluctrl 		= 		4'b0010;
					alusrc_A		=		1'b0;
					branch			=		1'b0;
					regwrite		=		1'b1;
					dmemwrite		=		1'b0;
					jump			=		1'b0;
					memtoreg		=		1'b0;
					noop			=		1'b0;						
					gpu_reg  = 1'b0;		
				end
			5'd6: //or																		
				begin
					aluctrl 		= 		4'b0011;
					alusrc_A		=		1'b0;
					branch			=		1'b0;
					regwrite		=		1'b1;
					dmemwrite		=		1'b0;
					jump			=		1'b0;
					memtoreg		=		1'b0;
					noop			=		1'b0;		
					gpu_reg  = 1'b0;		
				end
			5'd7: //xor																				
				begin
					aluctrl 		= 		4'b0100;
					alusrc_A		=		1'b0;
					branch			=		1'b0;
					regwrite		=		1'b1;
					dmemwrite		=		1'b0;
					jump			=		1'b0;
					memtoreg		=		1'b0;
					noop			=		1'b0;		
					gpu_reg  = 1'b0;		
				end
			5'd8: //mov		addi to zero offset																	
				begin
					aluctrl 		= 		4'b0000;
					alusrc_A		=		1'b0;
					branch			=		1'b0;
					regwrite		=		1'b1;
					dmemwrite		=		1'b0;
					jump			=		1'b0;
					memtoreg		=		1'b0;
					noop			=		1'b0;		
					gpu_reg  = 1'b0;		
				end
			5'd9: //cmp																				
				begin
					aluctrl 		= 		4'b0001;
					alusrc_A		=		1'b0;
					branch			=		1'b0;
					regwrite		=		1'b0;
					dmemwrite		=		1'b0;
					jump			=		1'b0;
					memtoreg		=		1'b0;
					noop			=		1'b0;		
					gpu_reg  = 1'b0;		
				end
			5'd10: //lsl																				
				begin
					aluctrl 		= 		4'b0110;
					alusrc_A		=		1'b0;
					branch			=		1'b0;
					regwrite		=		1'b1;
					dmemwrite		=		1'b0;
					jump			=		1'b0;
					memtoreg		=		1'b0;
					noop			=		1'b0;		
					gpu_reg  = 1'b0;		
				end
			5'd11: //lsr																				
				begin
					aluctrl 		= 		4'b0111;
					alusrc_A		=		1'b0;
					branch			=		1'b0;
					regwrite		=		1'b1;
					dmemwrite		=		1'b0;
					jump			=		1'b0;
					memtoreg		=		1'b0;
					noop			=		1'b0;		
					gpu_reg  = 1'b0;		
				end
			5'd12: //b																				
				begin
					aluctrl 		= 		4'b0000;
					alusrc_A		=		1'b1;
					branch			=		1'b1;
					regwrite		=		1'b0;
					dmemwrite		=		1'b0;
					jump			=		1'b0;
					memtoreg		=		1'b0;
					noop			=		1'b0;		
					gpu_reg  = 1'b0;		
				end
			5'd13: //jump																				
				begin
					aluctrl 		= 		4'b0000;
					alusrc_A		=		1'b0;
					branch			=		1'b0;
					regwrite		=		1'b0;
					dmemwrite		=		1'b0;
					jump			=		1'b1;
					memtoreg		=		1'b0;
					noop			=		1'b0;		
					gpu_reg  = 1'b0;		
				end
			5'd14: //gpu_fma																				
				begin
					aluctrl 		= 		4'b0000;
					alusrc_A		=		1'b0;
					branch			=		1'b0;
					regwrite		=		1'b0;
					dmemwrite		=		1'b0;
					jump			=		1'b0;
					memtoreg		=		1'b0;
					noop			=		1'b0;
					gpu_reg  = 1'b1;		
				end
		endcase
	end

assign gpu_out = gpu_reg;
endmodule
