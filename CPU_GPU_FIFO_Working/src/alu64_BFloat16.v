`timescale 1ns / 1ps

module alu_64_GPU(
    input  wire [63:0] A,           
    input  wire [3:0]  ALUOp,       
    input  wire [63:0] B,           
    output reg  [63:0] O,           
    output wire        N,           
    output wire        V,           
    output wire        C,           
    output wire        Z            
);
    // Integer Path Logic (32-bit operations)
    wire [31:0] A32 = A[31:0];
    wire [31:0] B32 = B[31:0];
    reg [32:0] int_res; 

    always @(*) begin
        case (ALUOp)
            4'b0000: int_res = {1'b0, A32} + {1'b0, B32}; // ADD 
            4'b0001: int_res = {1'b0, A32} - {1'b0, B32}; // SUB 
            4'b0010: int_res = {1'b0, A32} - {1'b0, B32}; // COMP
            default: int_res = 33'b0;
        endcase
    end

    // Assign Final 64-bit Output
    always @(*) begin
        case (ALUOp)
            4'b0000, 4'b0001, 4'b0010: O = {{32{int_res[31]}}, int_res[31:0]};
            4'b1010: O = ($signed(A32) < $signed(B32)) ? 64'd1 : 64'd0; // SLT
            default: O = 64'b0;
        endcase
    end

    // Status Flags
    assign Z = (O[31:0] == 32'b0);
    assign N = O[63]; 
    assign C = (ALUOp[3:2] == 2'b00) ? int_res[32] : 1'b0; 
    assign V = (ALUOp == 4'b0000) ? (~(A32[31] ^ B32[31]) & (A32[31] ^ int_res[31])) :
               (ALUOp == 4'b0001 || ALUOp == 4'b0010) ? ((A32[31] ^ B32[31]) & (A32[31] ^ int_res[31])) : 1'b0;

endmodule