`timescale 1ns / 1ps

module network_proc_full_tb;

  // --- Parameters ---
  localparam DATA_WIDTH       = 64;
  localparam CTRL_WIDTH       = 8;
  localparam FIFO_DEPTH_WORDS = 256;
  localparam UDP_REG_SRC_WIDTH = 2;
  localparam CLK_PERIOD       = 200; 
  
  integer i;

  // --- Inputs to UUT ---
  reg                         clk;
  reg                         reset;
  
  // Data path inputs
  reg  [DATA_WIDTH-1:0]       in_data;
  reg  [CTRL_WIDTH-1:0]       in_ctrl;
  reg                         in_wr;
  reg                         out_rdy;

  // Legacy / Direct Debug Ports
  reg  [8:0]                  debug_pc;
  reg                         debug_enable;
  reg  [31:0]                 debug_instr_in;
  reg                         debug_instr_write_en;

  // 32-Bit Register Inputs
  reg  [31:0]                 fifo_dmem_interact;
  reg  [31:0]                 fifo_dmem_r_addr;
  reg  [31:0]                 sw_reset;
  
  reg  [31:0]                 cpu_imem_wdata;
  reg  [31:0]                 cpu_imem_rw_address;
  reg  [31:0]                 cpu_imem_write;
  reg  [31:0]                 cpu_imem_interact;
  
  reg  [31:0]                 gpu_imem_wdata;
  reg  [31:0]                 gpu_imem_rw_address;
  reg  [31:0]                 gpu_imem_write;
  reg  [31:0]                 gpu_imem_interact;

  // --- Outputs from UUT ---
  wire [DATA_WIDTH-1:0]       out_data;
  wire [CTRL_WIDTH-1:0]       out_ctrl;
  wire                        out_wr;
  wire                        in_rdy;
  
  wire [31:0]                 debug_instr_out;
  wire [8:0]                  PC_END;

  // --- Testbench internal variables ---
  integer sent_word_count;

  // --- Instantiate the Unit Under Test (UUT) ---
  network_processor #(
    .DATA_WIDTH(DATA_WIDTH),
    .CTRL_WIDTH(CTRL_WIDTH),
    .FIFO_DEPTH_WORDS(FIFO_DEPTH_WORDS),
    .UDP_REG_SRC_WIDTH(UDP_REG_SRC_WIDTH)
  ) uut (
    .out_data(out_data),
    .out_ctrl(out_ctrl),
    .out_wr(out_wr),
    .out_rdy(out_rdy),
    .in_data(in_data),
    .in_ctrl(in_ctrl),
    .in_wr(in_wr),
    .in_rdy(in_rdy),
    .debug_pc(debug_pc),
    .debug_enable(debug_enable),
    .debug_instr_in(debug_instr_in),
    .debug_instr_write_en(debug_instr_write_en),
    .debug_instr_out(debug_instr_out),
    .PC_END(PC_END),
    .clk(clk),
    .reset(reset),
    
    // 32-bit Software Registers
    .fifo_dmem_interact(fifo_dmem_interact),
    .fifo_dmem_r_addr(fifo_dmem_r_addr),
    .sw_reset(sw_reset),
    .cpu_imem_wdata(cpu_imem_wdata),
    .cpu_imem_rw_address(cpu_imem_rw_address),
    .cpu_imem_write(cpu_imem_write),
    .cpu_imem_interact(cpu_imem_interact),
    .gpu_imem_wdata(gpu_imem_wdata),
    .gpu_imem_rw_address(gpu_imem_rw_address),
    .gpu_imem_write(gpu_imem_write),
    .gpu_imem_interact(gpu_imem_interact)
  );

  // --- Clock generator ---
  always #(CLK_PERIOD/2) clk = ~clk;

  // --- Helper Tasks ---
  task load_gpu_instr;
    input [31:0] addr;
    input [31:0] instr;
    begin
      @(posedge clk);
      gpu_imem_rw_address <= addr;
      gpu_imem_wdata      <= instr;
      gpu_imem_write      <= 32'd1;
      @(posedge clk);
      gpu_imem_write      <= 32'd0;
    end
  endtask

  task send_word;
    input [CTRL_WIDTH-1:0] ctrl;
    input [DATA_WIDTH-1:0] data;
    begin
      wait(in_rdy);
      @(posedge clk);
      in_data <= data;
      in_ctrl <= ctrl;
      in_wr   <= 1'b1;
      sent_word_count = sent_word_count + 1;
      @(posedge clk);
      in_wr   <= 1'b0;
      in_data <= 64'bx;
      in_ctrl <= 8'bx;
    end
  endtask

  // --- Main Test Sequence ---
  initial begin
    // 1. Initialize Inputs
    clk = 1'b0;
    reset = 1'b1;
    in_data = 64'bx;
    in_ctrl = 8'bx;
    in_wr = 1'b0;
    out_rdy = 1'b0; 
    
    debug_pc = 0; debug_enable = 0; debug_instr_in = 0; debug_instr_write_en = 0;
    sw_reset = 32'd0; fifo_dmem_interact = 32'd0; fifo_dmem_r_addr = 32'd0;
    cpu_imem_interact = 32'd0; cpu_imem_write = 32'd0; cpu_imem_rw_address = 32'd0; cpu_imem_wdata = 32'd0;
    gpu_imem_interact = 32'd0; gpu_imem_write = 32'd0; gpu_imem_rw_address = 32'd0; gpu_imem_wdata = 32'd0;

    sent_word_count = 0;

    #1000;
    reset = 1'b0; 
    #1000;

    $display("--- Starting Pipeline Setup ---");

    // 2. Freeze Pipeline & Assert SW Reset
    sw_reset           = 32'd1; // Assert reset
    cpu_imem_interact  = 32'd1; // Freeze CPU 
    gpu_imem_interact  = 32'd1; // Freeze GPU 
    fifo_dmem_interact = 32'd1; // Freeze FIFO
    #500;

    // 3. Load Instructions into GPU (As provided)
    $display("Loading GPU Instructions...");
    load_gpu_instr(32'd0,  32'h00000000); 
    load_gpu_instr(32'd1,  32'hFC000000); // HALT (Warning: Execution will stop here!)
    load_gpu_instr(32'd2,  32'h00000000); 
    load_gpu_instr(32'd3,  32'h00000000); 
    load_gpu_instr(32'd4,  32'h8C010007); // LW $1, 8($0)
    load_gpu_instr(32'd5,  32'h8C020008); // LW $2, 9($0)
    load_gpu_instr(32'd6,  32'h8C060009); // LW $6, 10($0)
    
    // NOPs for data hazard
    load_gpu_instr(32'd7,  32'h00000000); 
    load_gpu_instr(32'd8,  32'h00000000); 
    load_gpu_instr(32'd9,  32'h00000000); 
    load_gpu_instr(32'd10, 32'h00000000); 
    load_gpu_instr(32'd11, 32'h00000000); 
    
    // Math Operation
    load_gpu_instr(32'd12, 32'h14223000); // MULTFP $6, $1, $2
    
    // NOPs for writeback
    load_gpu_instr(32'd13, 32'h00000000); 
    load_gpu_instr(32'd14, 32'h00000000); 
    load_gpu_instr(32'd15, 32'h00000000); 
    load_gpu_instr(32'd16, 32'h00000000); 
    load_gpu_instr(32'd17, 32'h00000000); 
    
    // Store and finish
    load_gpu_instr(32'd18, 32'hAC060009); // SW $6, 10($0)
    load_gpu_instr(32'd19, 32'h240001ED); 
    load_gpu_instr(32'd20, 32'h00000000); 
    load_gpu_instr(32'd21, 32'h00000000); 
    load_gpu_instr(32'd22, 32'h00000000); 

    // 4. Release Resets & Unfreeze (Enter RUN STATE)
    $display("Unfreezing Pipeline...");
    cpu_imem_interact  = 32'd0;
    gpu_imem_interact  = 32'd0;
    fifo_dmem_interact = 32'd0;
    sw_reset           = 32'd0;
    #500;

    // 5. Send Network Packet Data
    $display("--- Sending MATH DATA (UDP) Packet ---");
    send_word(8'hFF, 64'h008000080006003C); 
    send_word(8'h00, 64'h004E46324303A036); 
    send_word(8'h00, 64'h9F0A0EB008060001); 
    send_word(8'h00, 64'h080006040001A036); 
    send_word(8'h00, 64'h9F0A0EB00A000F03); 
    send_word(8'h00, 64'h0000000000000A00); 
    send_word(8'h00, 64'h0F02000000000000); 
    send_word(8'h00, 64'h0000000000000000); 
    send_word(8'h10, 64'h0000000000B91D68); // End of Packet

    #2000;
    out_rdy <= 1'b1;
    #30000; 
    out_rdy <= 1'b0;

    $display("--- Sending TRIGGER/bfloat16 Packet ---");
    send_word(8'hFF, 64'h0001001100060088);
    send_word(8'h00, 64'hA0369F0A5F4B004E);
    send_word(8'h00, 64'h4632430008004500);
    send_word(8'h00, 64'h007A168F40003F11);
    send_word(8'h00, 64'hF5DE0A000F030A00);
    send_word(8'h00, 64'h0C03B88B138A0066);
    send_word(8'h00, 64'h42E2AAAAAAAAAAAA);
    send_word(8'h00, 64'hC0DEFACE0000000F); // TRIGGER
    send_word(8'h00, 64'h3E943ED73F193EE1);
    send_word(8'h00, 64'h3ECC3F0CBE383F38);
    send_word(8'h00, 64'h3F4FBE613F21BEE6);
    send_word(8'h00, 64'h3E8ABF193EAE3F61);
    send_word(8'h00, 64'hBE193EFABF453EA8);
    send_word(8'h00, 64'h3E993D4CBE4C3DCC);
    send_word(8'h00, 64'h3F28BE8ABF073F68);
    send_word(8'h00, 64'h000000000000BDF5); // bfloat16
    send_word(8'h00, 64'h0000000000000000); // bfloat16
    send_word(8'h00, 64'h0000000000000000);
    send_word(8'h01, 64'h0000000000000000); // End of Packet

    #25;
    out_rdy <= 1'b1;

    #1200000; // Allow sufficient processing time
    $display("Simulation Complete.");
    $stop;
  end

endmodule