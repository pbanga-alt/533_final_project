///////////////////////////////////////////////////////////////////////////////
// Module: logic_analyzer.v
// Project: NF2.1
// Description: Simple logic analyzer core with explicit state machine
///////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps

module logic_analyzer_bram
   (
      // Monitored signals (256 bits = 4x 64-bit signals)
      input  [63:0]   monitor_sig0,
      input  [63:0]   monitor_sig1,
      input  [63:0]   monitor_sig2,
      input  [63:0]   monitor_sig3,
      input           trigger,
      input           arm,             // Arm signal to start monitoring
      input  [5:0]    la_read_addr,      
      output [2:0]    la_status,      // 000=IDLE, 001=ARMED, 010=CAPTURING, 100=DONE
      output [255:0]  la_dout,       
      
      input           clk,
      input           reset
   );

   // State definitions
   localparam IDLE      = 3'b000;
   localparam ARMED     = 3'b001;
   localparam CAPTURING = 3'b010;
   localparam DONE      = 3'b100;

   wire [255:0] monitor_data;
   reg  [2:0] state;
   reg  [5:0] la_write_addr;
   wire we;

   assign monitor_data = {monitor_sig3, monitor_sig2, monitor_sig1, monitor_sig0};
   assign la_status = state;
   
   // Combinational write enable
   assign we = ((state == ARMED) && trigger) || (state == CAPTURING);
   
   // Memory is actually 256x64 wide
   la_64x256b la_uut(
      .addra(la_write_addr),
      .addrb(la_read_addr),
      .clka(clk),
      .clkb(clk),
      .dina(monitor_data),
      .doutb(la_dout),
      .wea(we)
   );


   // State machine
   always @(posedge clk) begin
      if (reset) begin
         state <= IDLE;
         la_write_addr <= 0;
      end
      else begin
         case (state)
            IDLE: begin
               la_write_addr <= 0;
               if (arm) begin
                  state <= ARMED;
               end
            end
            
            ARMED: begin
               if (trigger) begin
                  state <= CAPTURING;
               end
            end
            
            CAPTURING: begin
               la_write_addr <= la_write_addr + 1;
               
               if (la_write_addr == 6'd63) begin
                  state <= DONE;
                  la_write_addr <= 0;
               end
            end
            
            DONE: begin
               // Stay here until reset
            end
            
            default: begin
               state <= IDLE;
            end
         endcase
      end
   end

endmodule