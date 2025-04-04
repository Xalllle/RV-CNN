`timescale 1ns / 1ps

module datamemory#(
    parameter DM_ADDRESS = 9 ,
    parameter DATA_W = 32
    )(
    input logic clk,
    input logic MemRead , // comes from control unit
    input logic MemWrite , // Comes from control unit
    input logic [ DM_ADDRESS -1:0] a , // Read / Write address - 9 LSB bits of the ALU output
    input logic [ DATA_W -1:0] wd , // Write Data
    input logic [2:0] Funct3, // bits 12 to 14 of the instruction
    output logic [ DATA_W -1:0] rd // Read Data
    );

    logic [DATA_W-1:0] mem [(2**DM_ADDRESS)-1:0];

    // Combinational logic for reading from memory
    always_comb
    begin
      if(MemRead)
      begin
          case(Funct3)
          3'b000: //LB - Load Byte (sign-extended)
              // If sign bit (mem[a][7]) is 1, extend with 1s, else extend with 0s
              rd = {mem[a][7]? 24'hFFFFFF : 24'b0, mem[a][7:0]};
          3'b001: //LH - Load Halfword (sign-extended)
              // If sign bit (mem[a][15]) is 1, extend with 1s, else extend with 0s
              rd = {mem[a][15]? 16'hFFFF : 16'b0, mem[a][15:0]};
          3'b010: //LW - Load Word
              rd = mem[a];
          3'b100: //LBU - Load Byte Unsigned
              // Extend with 0s regardless of the byte's value
              rd = {24'b0, mem[a][7:0]};
          3'b101: //LHU - Load Halfword Unsigned
              // Extend with 0s regardless of the halfword's value
              rd = {16'b0, mem[a][15:0]};
          default:
              // Default behavior, could be LW or assign 'x if Funct3 value is unexpected
              rd = mem[a]; // Or assign 'x: rd = 'x;
          endcase
      end
      else // *** FIX: Added else block ***
      begin
          // Assign a default value when not reading.
          // '0' is often safe, 'x' indicates unknown, 'z' for high-impedance buses.
          rd = '0;
      end
    end

    // Sequential logic for writing to memory
    always @(posedge clk)
    begin
      if (MemWrite)
      begin
          case(Funct3)
          3'b000: //SB - Store Byte
              mem[a][7:0] =  wd[7:0];
          3'b001: //SH - Store Halfword
              mem[a][15:0] = wd[15:0];
          3'b010: //SW - Store Word
              mem[a] = wd;
          default: // No action for unsupported Funct3 during store, or could assign 'x
              mem[a] = wd; // Defaulting to SW might be intended, or handle error
          endcase
      end
    end

endmodule