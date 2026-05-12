`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    00:28:41 03/09/2026 
// Design Name: 
// Module Name:    cpu2 
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
module cpu2
    #(
      parameter DATA_WIDTH = 64,
      parameter CTRL_WIDTH = DATA_WIDTH/8,
      parameter UDP_REG_SRC_WIDTH = 2
   )
   (
      // misc
      input  reset,
      input  clk,
      output reg gpu_start,
      output mem_we,
      input [63:0] mem_dout,
      output [63:0]  mem_din,
      output [9:0] mem_addr_in,
      output [31:0] imem_out_la,
      input gpu_done,
				input [31:0] command_reg,
				input [63:0] mem_din_debug,
				input [31:0] mem_addr_debug,
      output reg[14:0] vec_size,
		output reg[9:0] start_mem_pointer_to_gpu,
		output reg[9:0] stop_mem_pointer_to_gpu,
      output [31:0] imem_dout_out,
		output reg local_gpu_reset,
		output [31:0] pc_la,
		output [63:0] r1_data,
		output reg cpu_done,
		output [31:0] cpu_status
   );

// bypass assignments
//assign out_data      =     in_data;
//assign in_rdy        =     out_rdy;                      //I have bypassed the connections for router
//assign out_ctrl      =     in_ctrl;
//assign out_wr        =     in_wr;

//--------------------------------------------------------------------------------------------------------------------------------------------------------------------//

//debug wires
wire           debug, imem_we_debug, dmem_web;                 //The address and data-in signals are common for register, imem and dmem interfaces. Write enable and dout are separate for each.
//wire [31:0]    mem_addr_debug, command_reg, 
wire [31:0] dpu_status;        //The imem and register port1 is muxed using debug to enter debug mode. Ddmem has dedicated portb for debug
wire [63:0]     dmem_doutb;  

//Debug assignments
assign imem_we_debug    =     command_reg[1];                           // This means we write 0x0a for imem write (include debug signal for muxing)
assign dmem_web         =     command_reg[2];                           // This means we write 0x0c for dmem write (debug mode not strictly required due to dedicated debug port)
assign debug            =     command_reg[3];                           // This means we write 0x08 for debug enable


// Logic Analyzer Signals
wire [63:0] 	la_monitor_sig0, la_monitor_sig1, la_monitor_sig2, la_monitor_sig3;     // We can monitor 256 bit with 64 depth. la_status==0(idle), 1(armed) 2(capturing), 4(done) 
wire [31:0] 	la_read_addr;                                                           // Current trigger is one hot coded with Instruction
wire [2:0] 	   la_status;
wire [255:0] 	la_dout;
wire 		      la_arm, la_reset, la_trigger;

//--------------------------------------------------------------------------------------------------------------------------------------------------------------------//
// Pipeline Registers
// IF Stage
reg [8:0]      pc_reg;                                                      // The code progression is like a data path along the signal route: origin to destination. Just follow the trail to troubleshoot.

// IF stage wires
wire [31:0]    imem_dout;                                            
wire [8:0]     imem_addr; //, if_pc_plus_1;
wire [8:0]     pc_next;

//assign         if_pc_plus_1   =  pc_reg + 1;
assign         imem_addr = debug? mem_addr_debug[8:0] : pc_reg;             //debug mux
// assign         pc_next = (ex_jump) ? idex_offset_reg : ((ex_branch_taken) ? ex_alu_dout[8:0] : pc_reg+1);  // Determine next pc

//--------------------------------------------------------------------------------------------------------------------------------------------------------------------//
// IF-ID Stage
//reg [31:0]     imem_dout;
//reg [8:0]      ifid_pc_plus_1_reg;                                          // carrying the pc+1 to compute the branch address in ex
reg [8:0]     ifid_pc_reg;                                             


// ID Stage wires
wire [63:0]    id_r2_data, id_r1_data;
assign r1_data = id_r1_data;
wire [8:0]     id_offset;
wire [3:0]     id_alu_op, id_passcond;                                       // Have to confirm the ALU opcode width with redesign
wire [2:0]     id_r1, id_r2, id_r3, id_reg1_addr;                            //Connected with register module 
wire           id_regwe, id_memwe, id_user_stall, id_m2r, id_trigger;                         // Control Signals
wire           id_alusrc_A, id_alusrc_B, id_branch, id_jump, id_noop, id_update_flags;

assign id_r1            =     imem_dout[12:10];
assign id_r2            =     imem_dout[15:13];
assign id_r3            =     imem_dout[18:16];                      // no reg_dst signal in the design as we use dedicated bits for destination register
assign id_offset        =     imem_dout[27:19];                      // 9 bit offset used for both branch, jump and immediate instructions
assign id_user_stall    =     imem_dout[30];
assign id_trigger       =     imem_dout[31];

assign id_reg1_addr     =  debug? mem_addr_debug[2:0] : id_r1;             //debug mux

//--------------------------------------------------------------------------------------------------------------------------------------------------------------------//

// ID-EX Stage Register
reg [63:0]     idex_r2_data_reg, idex_r1_data_reg;                                                       
reg [8:0]      idex_offset_reg; //idex_pc_plus_1_reg,
reg [8:0]      idex_pc_reg;
reg [3:0]      idex_passcond_reg, idex_alu_op_reg;                                   //check its width
reg [2:0]      idex_r3_reg;  
reg            idex_regwe_reg, idex_memwe_reg, idex_user_stall_reg, idex_m2r_reg, idex_noop_reg; 
reg            idex_alusrc_A_reg, idex_alusrc_B_reg, idex_branch_reg, idex_jump_reg, idex_update_flags_reg;

// Ex stage wires and Flags
reg            carry_flag, zero_flag, negative_flag, overflow_flag;                                      // FLAG Registers
wire           alu_carry, alu_zero, alu_negative, alu_overflow;                                          // output of alu feeding into FLAG registers
wire[63:0]     ex_alu_input2, ex_alu_input1, ex_alu_dout;                //connect with ALU and pass decoder
wire           ex_branch_taken, ex_pass, ex_jump;                                                                                                 


assign ex_alu_input1             =        idex_alusrc_A_reg?      ({{55{1'b0}}, idex_pc_reg} + 1'b1)                        :       idex_r1_data_reg;         
assign ex_alu_input2             =        idex_alusrc_B_reg?      {{55{idex_offset_reg[8]}}, idex_offset_reg}      :       idex_r2_data_reg;                         
assign ex_branch_taken           =        idex_branch_reg      &&    ex_pass;
assign ex_jump                   =        idex_jump_reg;

assign ex_alu_dout[63:32]        =        32'b0;                     // remove it later for extension to 64bit designs.

//--------------------------------------------------------------------------------------------------------------------------------------------------------------------//

// Ex-Mem Stage Registers
reg [63:0]     exmem_r2_data_reg, exmem_r1_data_reg;                                                       
reg [8:0]      exmem_offset_reg; //exmem_pc_plus_1_reg,
reg [8:0]      exmem_pc_reg; 
reg [3:0]      exmem_passcond_reg, exmem_alu_op_reg;                                   //check its width
reg [2:0]      exmem_r3_reg;  
reg            exmem_regwe_reg, exmem_memwe_reg, exmem_user_stall_reg, exmem_m2r_reg, exmem_noop_reg; 
reg            exmem_alusrc_A_reg, exmem_alusrc_B_reg, exmem_branch_reg, exmem_jump_reg, exmem_update_flags_reg;

reg [63:0]     exmem_alu_dout_reg;                               


//Mem stage wires
//wire [63:0]    mem_dout;                  

//--------------------------------------------------------------------------------------------------------------------------------------------------------------------//

// Mem-WB Stage

reg [63:0]     memwb_r2_data_reg, memwb_r1_data_reg;                                                       
reg [8:0]      memwb_pc_plus_1_reg, memwb_offset_reg;
reg [3:0]      memwb_passcond_reg, memwb_alu_op_reg;                                   //check its width
reg [8:0]      memwb_pc_reg;
reg [2:0]      memwb_r3_reg;  
reg            memwb_regwe_reg, memwb_memwe_reg, memwb_user_stall_reg, memwb_m2r_reg, memwb_noop_reg; 
reg            memwb_alusrc_A_reg, memwb_alusrc_B_reg, memwb_branch_reg, memwb_jump_reg, memwb_update_flags_reg;
reg [63:0]     memwb_alu_dout_reg;

reg [63:0]     memwb_mem_dout_reg;                  // wb_alu_data_reg not done 


// WB Stage Wires
wire [63:0]    wb_writeback_data;
wire [31:0] ctrl_status_0, ctrl_status_1, ctrl_status_2, ctrl_status_3, ctrl_status_4, ctrl_status_5, ctrl_status_6, ctrl_status_7; 
assign wb_writeback_data      =     memwb_m2r_reg? memwb_mem_dout_reg   :   memwb_alu_dout_reg;
//PP COMMIT -BEGIN
wire[31:0] alu_flags ;

assign alu_flags = {28'b0, carry_flag, overflow_flag, zero_flag, negative_flag};
//PP COMMIT -END
//--------------------------------------------------------------------------------------------------------------------------------------------------------------------//


//User stalling and break pointing logic
reg            user_pipe_overide_prev_reg;              
wire           pipe_en, user_pipe_en, user_pipe_overide_pulse, user_pipe_overide;                  //stalling logic for both user and instruction control of pipeline

assign user_pipe_en                 =        command_reg[0];                                                               // Enable when user wants to run the pipeline
assign user_pipe_overide            =        command_reg[30];                                                              // Enable when user wants to overide and enable a stalled pipeline
assign user_pipe_overide_pulse      =        user_pipe_overide && !user_pipe_overide_prev_reg;        // this pulse is produced every time command_reg[30] is pushed from 0 to 1
assign pipe_en                      =        user_pipe_overide_pulse || (user_pipe_en && !memwb_user_stall_reg);                // pulse is used to continue instruction stalled pipeline or single stepping instructions.

//--------------------------------------------------------------------------------------------------------------------------------------------------------------------//

//logic analyser assignments
assign la_arm                       =        command_reg[4];                           // command_reg=0x10 to arm LA
assign la_reset                     =        command_reg[5] | reset;                   // command_reg=0x20 to reset LA
assign la_trigger                   =        id_trigger;                         // instruction[31] bit is one hot coded for LA trigger

/*                                                                      // Connect the wires to monitor when required
// LA monitor signals 
assign la_monitor_sig0     =     {mem_dout, imem_we, 25'b0, mem_addr[5:0]};                          
assign la_monitor_sig1     =     {3'b0, dmem_wea, 3'b0, dmem_web, la_trigger, 7'b0, dmem_addra[7:0], dmem_addrb[7:0], imem_din};
assign la_monitor_sig2     =     command_reg[7]? dmem_dinb : dmem_dina;                                
assign la_monitor_sig3     =     command_reg[7]? dmem_doutb : dmem_douta; 
*/      
                          
assign dpu_status          =     {7'b0, pc_reg, 3'b0, pipe_en, 8'b0, 1'b0, la_status};   // status info - [24:16] - pc_reg | [12] - pipe_en | [2:0] - LA status - can add more status info in future

  
// Instantiate Logic Analyzer
logic_analyzer_bram la_inst (
   .monitor_sig0(la_monitor_sig0),
   .monitor_sig1(la_monitor_sig1),
   .monitor_sig2(la_monitor_sig2),
   .monitor_sig3(la_monitor_sig3),
   .trigger(la_trigger),
   .arm(la_arm),
   .la_read_addr(la_read_addr[5:0]),
   .la_status(la_status),
   .la_dout(la_dout),
   .clk(clk),
   .reset(la_reset)
);

// Instantiate the Instruction Memory
wire id_gpu_out;
wire [8:0] to_imem_addr = debug? mem_addr_debug[8:0] : (id_gpu_out& ~gpu_done) ? ifid_pc_reg : pc_reg;
// Instantiate the Instruction Memory
	imem_32x512_v1 uut_imem (
		.clk(clk), 
		.din(mem_din_debug[31:0]),    	//controlled by debug
		.addr(to_imem_addr),        	      //muxed for debug
		.we(imem_we_debug),      	      //controlled by debug
		.dout(imem_dout)         	      //tapped by debug
	);
//wire [31:0] pc_la;
wire id_cpu_done;
reg id_ex_cpu_done, ex_mem_cpu_done, mem_wb_cpu_done;
reg [11:0] addr_counter;
wire [11:0] to_la_addr = debug ?  mem_addr_debug[11:0] : addr_counter;
wire la_wea = debug ? 1'b0 : 1'b1;

	instruction_memory dev_pc_la (
		.clka(clk), 
		.clkb(clk), 
		.dina({15'd0,cpu_done,mem_wb_cpu_done,ex_mem_cpu_done,id_cpu_done,start,pipe_en,gpu_done,gpu_start,pc_reg}),    	//controlled by debug
		.dinb(32'd0),
		.addra(to_la_addr),        	      //muxed for debug
		.addrb(12'b0),        	      //muxed for debug
		.wea(la_wea),      	      //controlled by debug
		.web(1'b0),      	      //controlled by debug
		.douta(pc_la)         	      //tapped by debug
	);
	imem_32x512_v1 eee_imem_out_la (
		.clk(clk), 
		.din(imem_dout),    	//controlled by debug
		.addr(to_la_addr),        	      //muxed for debug
		.we(la_wea),      	      //controlled by debug
		.dout(imem_out_la)         	      //tapped by debug
	);



reg idex_gpu_out;
reg exmem_gpu_out;
reg memwb_gpu_out;
wire gpu_vec_size_wen;
// Instantiation of instruction decoder
cpudecoder uut_decoder(
.instr(imem_dout),
.alusrc_A(id_alusrc_A),
.alusrc_B(id_alusrc_B),
.aluctrl(id_alu_op),
.branch(id_branch),
.regwrite(id_regwe),
.dmemwrite(id_memwe),
.jump(id_jump),
.passcond(id_passcond),
.memtoreg(id_m2r),
.noop(id_noop),
.update_flags(id_update_flags),
.gpu_out(id_gpu_out),
.gpu_vec_size_out(gpu_vec_size_wen),
.cpu_done(id_cpu_done)
);


regfile_8 register_file (
    .clk(clk),
    .clr(reset),
    .raddr0(id_reg1_addr),             // muxed for debug
    .raddr1(id_r2),
    .waddr(memwb_r3_reg),
    .wdata(wb_writeback_data),
    .wea(memwb_regwe_reg),
    .rdata0(id_r1_data),
    .rdata1(id_r2_data)
);


// Instantiate the ALU
alu_32bit alu_uut(
   .a(ex_alu_input1[31:0]),
   .b(ex_alu_input2[31:0]),
   .alu_ctrl(idex_alu_op_reg),
   .alu_out(ex_alu_dout[31:0]),
   .v_flag(alu_overflow),
   .c_flag(alu_carry),
   .n_flag(alu_negative),
   .z_flag(alu_zero)
);


// Instantiating passdecoder 
passdecoder uut_passdecode(
   .compbits(idex_passcond_reg),
   .N(negative_flag),
   .Z(zero_flag),
   .V(overflow_flag),
   .C(carry_flag),
   .pass(ex_pass)
);


// Instantiate the dmem	
//	dmem_64x256_v1 uut_dmem(
//	.addra(ex_alu_dout[7:0]),
//	.addrb(mem_addr_debug[7:0]),     //controlled by debug - Port B is for debug
//	.clka(clk),
//	.clkb(clk),
//	.dina(idex_r2_data_reg),
//	.dinb(mem_din_debug),      //controlled by debug
//	.douta(mem_dout),
//	.doutb(dmem_doutb),    //controlled by debug
//	.wea(idex_memwe_reg),
//	.web(dmem_web)         //controlled by debug
//	);

//--------------------------------------------------------------------------------------------------------------------------------------------------------------------//

assign         pc_next = (id_gpu_out & ~gpu_done) ? ifid_pc_reg + 1 : ((ex_jump) ? idex_offset_reg : ((ex_branch_taken) ? ex_alu_dout[8:0] : pc_reg+1));  // Determine next pc

always @(posedge clk) begin   
   if (reset) begin   
      addr_counter <= 0;      
      user_pipe_overide_prev_reg    <=          0;
      pc_reg                        <=          0;
      //ifid_pc_plus_1_reg            <=          0;
	   //imem_dout              <=          0;
      ifid_pc_reg                   <=          0;
		gpu_start <= 0;
      //idex_pc_plus_1_reg            <=          0;
      idex_pc_reg                   <=          0;
      idex_offset_reg               <=          0;
      idex_user_stall_reg           <=          0;
	   idex_r1_data_reg              <=          0; 
      idex_r2_data_reg              <=          0;          
      idex_r3_reg                   <=          0;
      idex_regwe_reg                <=          0;
      idex_memwe_reg                <=          0;
      idex_m2r_reg                  <=          0;
      idex_alusrc_A_reg             <=          0;
      idex_alusrc_B_reg             <=          0;
      idex_branch_reg               <=          0;
      idex_jump_reg                 <=          0;
      idex_alu_op_reg               <=          0;
      idex_passcond_reg             <=          0;
      idex_noop_reg                 <=          0;
      idex_update_flags_reg         <=          0;

      carry_flag                    <=          0; 
      zero_flag                     <=          0;
      negative_flag                 <=          0;
      overflow_flag                 <=          0;

      exmem_pc_reg                  <=          0;
      exmem_user_stall_reg          <=          0;
	   exmem_r2_data_reg             <=          0;
      exmem_alu_dout_reg            <=          0;
      exmem_r3_reg                  <=          0;
      exmem_regwe_reg               <=          0;
      exmem_memwe_reg               <=          0;
      exmem_m2r_reg                 <=          0;
      exmem_noop_reg                <=          0;

      memwb_pc_reg                 <=          0;
      memwb_user_stall_reg          <=          0;
	   memwb_regwe_reg               <=          0;
      memwb_r3_reg                  <=          0;
      memwb_mem_dout_reg            <=          0;
      memwb_m2r_reg                 <=          0;
      memwb_alu_dout_reg            <=          0;
      memwb_noop_reg                <=          0;
		
		local_gpu_reset <= 0;
	   idex_gpu_out <= 0;
		exmem_gpu_out <= 0;
		memwb_gpu_out <= 0;
		cpu_done <= 0;
		id_ex_cpu_done <= 0;
		ex_mem_cpu_done <= 0;
		mem_wb_cpu_done <= 0;
      // Add all other registers in the module so they get reset
   end 
   else begin       
      user_pipe_overide_prev_reg    <=          user_pipe_overide;            // these are control registers which update above the pipeline - used to enable or stall pipeline

      if(pipe_en) begin                                                       // this segment updates the pipeline registers
         // if(ex_jump)
         //    pc_reg                  <=          idex_offset_reg;
         // else if(ex_branch_taken)
         //    pc_reg                  <=          ex_alu_dout[8:0];
         // else
         //    pc_reg                  <=          if_pc_plus_1;                 // Program counter update and branching logic with higher priority to jump
  //      if(!gpu_start 
	pc_reg <= pc_next;

         if(addr_counter < 2000) begin
 	addr_counter <= addr_counter + 1;
	end      
         
         //imem_dout           <=          imem_dout;                    // IF-ID stage logic updates
         //ifid_pc_plus_1_reg         <=          if_pc_plus_1;
         ifid_pc_reg                <=          (id_gpu_out & ~gpu_done)? ifid_pc_reg : pc_reg;

         //idex_pc_plus_1_reg         <=          ifid_pc_plus_1_reg;
         idex_pc_reg                <=          ifid_pc_reg;
         idex_r1_data_reg           <=          id_r1_data;
         idex_r2_data_reg           <=          id_r2_data;   
         idex_r3_reg                <=          id_r3;
         idex_offset_reg            <=          id_offset;                    // ID-EX stage logic updates
         idex_m2r_reg               <=          id_m2r;
         idex_alusrc_A_reg          <=          id_alusrc_A;
         idex_alusrc_B_reg          <=          id_alusrc_B;
         idex_alu_op_reg            <=          id_alu_op;
         idex_passcond_reg          <=          id_passcond;                           
         idex_user_stall_reg        <=          id_user_stall;      
         idex_regwe_reg             <=          id_regwe; 
         idex_memwe_reg             <=          id_memwe; 
         idex_branch_reg            <=          id_branch; 
         idex_jump_reg              <=          id_jump;
         idex_noop_reg              <=          id_noop; 
         idex_update_flags_reg      <=          id_update_flags;

         if((!idex_noop_reg)&&(idex_update_flags_reg)) begin
            carry_flag              <=          alu_carry; 
            zero_flag               <=          alu_zero;                            // FLAG registers updates
            negative_flag           <=          alu_negative;
            overflow_flag           <=          alu_overflow;
         end

         exmem_pc_reg               <=          idex_pc_reg;
         exmem_r2_data_reg          <=          idex_r2_data_reg; //connect directly no latch
         exmem_alu_dout_reg         <=          ex_alu_dout;
         exmem_r3_reg               <=          idex_r3_reg;
         exmem_m2r_reg              <=          idex_m2r_reg;
         exmem_user_stall_reg       <=          idex_user_stall_reg;
         exmem_regwe_reg            <=          idex_regwe_reg        &&    ex_pass;
         exmem_memwe_reg            <=          idex_memwe_reg        &&    ex_pass;              
         exmem_noop_reg             <=          idex_noop_reg;                            // EX-Mem stage logic updates

         memwb_pc_reg               <=          exmem_pc_reg;
         memwb_m2r_reg              <=          exmem_m2r_reg;
         memwb_alu_dout_reg         <=          exmem_alu_dout_reg;
         memwb_user_stall_reg       <=          exmem_user_stall_reg;
         memwb_regwe_reg            <=          exmem_regwe_reg;

         memwb_r3_reg               <=          exmem_r3_reg;
         memwb_mem_dout_reg         <=          mem_dout;                     // Mem-WB stage logic updates
         memwb_noop_reg             <=          exmem_noop_reg;
			
			id_ex_cpu_done <= id_cpu_done;
			ex_mem_cpu_done <= id_ex_cpu_done;
			mem_wb_cpu_done <= ex_mem_cpu_done;
//wire id_gpu_out;
idex_gpu_out <= id_gpu_out;
exmem_gpu_out <= idex_gpu_out;
memwb_gpu_out <= exmem_gpu_out;
	if(id_gpu_out == 1) gpu_start <= 1;
	else gpu_start <= 0; 
	if(gpu_done == 1) begin
	gpu_start <= 0;
	local_gpu_reset <= 1;
	end
	else local_gpu_reset <= 0;
	if(gpu_vec_size_wen) begin
	vec_size <= imem_dout[9:5];
	start_mem_pointer_to_gpu <= imem_dout[19:10];
	stop_mem_pointer_to_gpu <= imem_dout[29:20];
	end
	
	
	if(mem_wb_cpu_done) cpu_done <= 1;
	else cpu_done <= 0;
         // add all the registers to be updated only if pipe_en active, else values will be held same. 
      end
   end
end


// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------//


assign mem_we = idex_memwe_reg;
//wire [63:0] mem_dout_out = mem_dout;
assign mem_din = idex_r2_data_reg;
assign mem_addr_in = ex_alu_dout[9:0];
assign imem_dout_out = imem_dout;
assign cpu_status = {21'd0,gpu_done,id_gpu_out,pc_reg};
endmodule


