module riscv_alu #(
    parameter XLEN = 32
) (
    input  logic [XLEN-1:0] operand_a,
    input  logic [XLEN-1:0] operand_b,
    input  logic [3:0]      alu_op,
    output logic [XLEN-1:0] alu_result
);

    localparam ALU_ADD  = 4'b0000;
    localparam ALU_SUB  = 4'b0001;
    localparam ALU_SLT  = 4'b0010;
    localparam ALU_SLTU = 4'b0011;
    localparam ALU_XOR  = 4'b0100;
    localparam ALU_OR   = 4'b0101;
    localparam ALU_AND  = 4'b0110;
    localparam ALU_SLL  = 4'b0111;
    localparam ALU_SRL  = 4'b1000;
    localparam ALU_SRA  = 4'b1001;
    localparam ALU_MUL  = 4'b1010; // Assuming MUL is needed, though not used in base I-set

    logic [XLEN-1:0] operand_b_neg;
    logic [XLEN-1:0] shift_amount;
    logic [2*XLEN-1:0] mul_result_full; // Only needed if MUL is used

    assign operand_b_neg = ~operand_b + 1;
    assign shift_amount = operand_b[$clog2(XLEN)-1:0];
    assign mul_result_full = operand_a * operand_b; // Only needed if MUL is used

    always_comb begin
        alu_result = {XLEN{1'bx}};
        case (alu_op)
            ALU_ADD:  alu_result = operand_a + operand_b;
            ALU_SUB:  alu_result = operand_a + operand_b_neg;
            ALU_SLT:  alu_result = ($signed(operand_a) < $signed(operand_b)) ? {{XLEN-1{1'b0}}, 1'b1} : {XLEN{1'b0}};
            ALU_SLTU: alu_result = (operand_a < operand_b) ? {{XLEN-1{1'b0}}, 1'b1} : {XLEN{1'b0}};
            ALU_XOR:  alu_result = operand_a ^ operand_b;
            ALU_OR:   alu_result = operand_a | operand_b;
            ALU_AND:  alu_result = operand_a & operand_b;
            ALU_SLL:  alu_result = operand_a << shift_amount;
            ALU_SRL:  alu_result = operand_a >> shift_amount;
            ALU_SRA:  alu_result = $signed(operand_a) >>> shift_amount;
            // ALU_MUL:  alu_result = mul_result_full[XLEN-1:0]; // Keep if M extension needed
            default:  alu_result = {XLEN{1'bx}};
        endcase
    end
endmodule

// Simple Register File
module reg_file #(
    parameter XLEN = 32,
    parameter REG_COUNT = 32
) (
    input  logic clk,
    input  logic rst_n,
    input  logic we_wb,          // Write enable from WB stage
    input  logic [4:0] rs1_addr_id,  // Read address 1 (ID stage)
    input  logic [4:0] rs2_addr_id,  // Read address 2 (ID stage)
    input  logic [4:0] rd_addr_wb,   // Write address (WB stage)
    input  logic [XLEN-1:0] rd_data_wb, // Write data (WB stage)
    output logic [XLEN-1:0] rs1_data_id, // Read data 1
    output logic [XLEN-1:0] rs2_data_id  // Read data 2
);

    logic [XLEN-1:0] registers [REG_COUNT-1:0];
    integer i;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < REG_COUNT; i = i + 1) begin
                registers[i] <= {XLEN{1'b0}};
            end
        end else begin
            if (we_wb && (rd_addr_wb != 5'b0)) begin // Write only if enabled and not x0
                registers[rd_addr_wb] <= rd_data_wb;
            end
        end
    end

    assign rs1_data_id = (rs1_addr_id == 5'b0) ? {XLEN{1'b0}} : registers[rs1_addr_id];
    assign rs2_data_id = (rs2_addr_id == 5'b0) ? {XLEN{1'b0}} : registers[rs2_addr_id];

endmodule

// Immediate Generator
module imm_gen #(
    parameter XLEN = 32
) (
    input  logic [31:0] instr_id,
    output logic [XLEN-1:0] imm_id
);
    logic [6:0] opcode;
    assign opcode = instr_id[6:0];

    localparam OPC_LUI    = 7'b0110111;
    localparam OPC_AUIPC  = 7'b0010111;
    localparam OPC_JAL    = 7'b1101111;
    localparam OPC_JALR   = 7'b1100111;
    localparam OPC_BRANCH = 7'b1100011;
    localparam OPC_LOAD   = 7'b0000011;
    localparam OPC_STORE  = 7'b0100011;
    localparam OPC_IMM    = 7'b0010011;
    localparam OPC_REG    = 7'b0110011;

    always_comb begin
        case (opcode)
            OPC_LOAD:   imm_id = {{20{instr_id[31]}}, instr_id[31:20]}; // I-type
            OPC_IMM:    imm_id = {{20{instr_id[31]}}, instr_id[31:20]}; // I-type (ADDI, SLTI, etc.)
            OPC_JALR:   imm_id = {{20{instr_id[31]}}, instr_id[31:20]}; // I-type
            OPC_STORE:  imm_id = {{20{instr_id[31]}}, instr_id[31:25], instr_id[11:7]}; // S-type
            OPC_BRANCH: imm_id = {{19{instr_id[31]}}, instr_id[31], instr_id[7], instr_id[30:25], instr_id[11:8], 1'b0}; // B-type
            OPC_LUI:    imm_id = {instr_id[31:12], 12'b0}; // U-type
            OPC_AUIPC:  imm_id = {instr_id[31:12], 12'b0}; // U-type
            OPC_JAL:    imm_id = {{11{instr_id[31]}}, instr_id[31], instr_id[19:12], instr_id[20], instr_id[30:21], 1'b0}; // J-type
            default:    imm_id = {XLEN{1'bx}}; // Should not happen for valid instructions
        endcase
    end

endmodule

// Control Unit (Simplified - CORRECTED)
module control_unit (
    input  logic [6:0] opcode,
    input  logic [2:0] funct3, // Needed for some opcodes
    input  logic       funct7b5, // Bit 5 of funct7 (for SUB/SRA)
    output logic       reg_write_en, // Enable writing to register file
    output logic [1:0] alu_src_b,    // 00: reg, 01: imm, 10: pc+4 (for JAL/JALR)
    output logic [3:0] alu_op,       // ALU operation code
    output logic       mem_read_en,  // Enable memory read (for LW)
    output logic       mem_write_en, // Enable memory write (for SW)
    output logic [1:0] wb_mux_sel,   // 00: ALU result, 01: Mem data, 10: PC+4
    output logic       branch,       // Is a branch instruction
    output logic       jump          // Is a jump instruction (JAL/JALR)
);
    // --- Local parameters matching riscv_alu ---
    localparam ALU_ADD  = 4'b0000;
    localparam ALU_SUB  = 4'b0001;
    // Add other ALU op codes if needed by instructions below

    // --- Opcode parameters ---
    localparam OPC_LUI    = 7'b0110111;
    localparam OPC_AUIPC  = 7'b0010111;
    localparam OPC_JAL    = 7'b1101111;
    localparam OPC_JALR   = 7'b1100111;
    localparam OPC_BRANCH = 7'b1100011;
    localparam OPC_LOAD   = 7'b0000011;
    localparam OPC_STORE  = 7'b0100011;
    localparam OPC_IMM    = 7'b0010011;
    localparam OPC_REG    = 7'b0110011;

    localparam ALU_SRC_REG = 2'b00;
    localparam ALU_SRC_IMM = 2'b01;

    localparam WB_MUX_ALU = 2'b00;
    localparam WB_MUX_MEM = 2'b01;
    localparam WB_MUX_PC4 = 2'b10; // For JAL/JALR link address

    // Default values (NOP-like)
    assign reg_write_en = 1'b0;
    assign alu_src_b    = ALU_SRC_REG;
    assign alu_op       = 4'bxxxx; // Default undefined
    assign mem_read_en  = 1'b0;
    assign mem_write_en = 1'b0;
    assign wb_mux_sel   = WB_MUX_ALU;
    assign branch       = 1'b0;
    assign jump         = 1'b0;

    always_comb begin
        case (opcode)
            OPC_REG: begin // R-type (ADD, SUB, etc.)
                reg_write_en = 1'b1;
                alu_src_b    = ALU_SRC_REG;
                mem_read_en  = 1'b0;
                mem_write_en = 1'b0;
                wb_mux_sel   = WB_MUX_ALU;
                branch       = 1'b0;
                jump         = 1'b0;
                case (funct3)
                    // *** CORRECTED: Removed backticks ***
                    3'b000: alu_op = funct7b5 ? ALU_SUB : ALU_ADD; // ADD/SUB
                    // Add other R-type funct3 cases here (SLT, SLTU, XOR, OR, AND, SLL, SRL, SRA)
                    default: alu_op = 4'bxxxx;
                endcase
            end
            OPC_IMM: begin // I-type (ADDI, SLTI, etc.)
                reg_write_en = 1'b1;
                alu_src_b    = ALU_SRC_IMM;
                mem_read_en  = 1'b0;
                mem_write_en = 1'b0;
                wb_mux_sel   = WB_MUX_ALU;
                branch       = 1'b0;
                jump         = 1'b0;
                case (funct3)
                     // *** CORRECTED: Removed backticks ***
                    3'b000: alu_op = ALU_ADD; // ADDI
                    // Add other I-type funct3 cases here (SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI)
                    default: alu_op = 4'bxxxx;
                endcase
            end
            OPC_LOAD: begin // LW
                reg_write_en = 1'b1;
                alu_src_b    = ALU_SRC_IMM; // Immediate offset for address calculation
                // *** CORRECTED: Removed backticks ***
                alu_op       = ALU_ADD;    // Calculate address: rs1 + imm
                mem_read_en  = 1'b1;
                mem_write_en = 1'b0;
                wb_mux_sel   = WB_MUX_MEM; // Write back data from memory
                branch       = 1'b0;
                jump         = 1'b0;
            end
            OPC_STORE: begin // SW
                reg_write_en = 1'b0; // No register write
                alu_src_b    = ALU_SRC_IMM; // Immediate offset for address calculation
                 // *** CORRECTED: Removed backticks ***
                alu_op       = ALU_ADD;    // Calculate address: rs1 + imm
                mem_read_en  = 1'b0;
                mem_write_en = 1'b1;       // Write rs2 data to memory
                branch       = 1'b0;
                jump         = 1'b0;
            end
            OPC_BRANCH: begin // BEQ, BNE, etc.
                reg_write_en = 1'b0;
                alu_src_b    = ALU_SRC_REG; // Compare registers
                 // *** CORRECTED: Removed backticks ***
                alu_op       = ALU_SUB;    // Use SUB for comparison (check zero flag later)
                mem_read_en  = 1'b0;
                mem_write_en = 1'b0;
                branch       = 1'b1;       // Is a branch instruction
                jump         = 1'b0;
            end
             OPC_JAL: begin
                reg_write_en = 1'b1;
                alu_src_b    = ALU_SRC_IMM; // Not directly used by ALU, but imm needed for target
                 // *** CORRECTED: Removed backticks ***
                alu_op       = ALU_ADD;    // Used to calculate PC+imm, but also need PC+4
                mem_read_en  = 1'b0;
                mem_write_en = 1'b0;
                wb_mux_sel   = WB_MUX_PC4; // Write back PC+4
                branch       = 1'b0;
                jump         = 1'b1;       // Is a jump
            end
             OPC_JALR: begin
                reg_write_en = 1'b1;
                alu_src_b    = ALU_SRC_IMM; // Used for target calculation (rs1+imm)
                 // *** CORRECTED: Removed backticks ***
                alu_op       = ALU_ADD;    // Calculate target address
                mem_read_en  = 1'b0;
                mem_write_en = 1'b0;
                wb_mux_sel   = WB_MUX_PC4; // Write back PC+4
                branch       = 1'b0;
                jump         = 1'b1;       // Is a jump
            end
             OPC_LUI: begin
                reg_write_en = 1'b1;
                alu_src_b    = ALU_SRC_IMM; // Pass immediate through
                 // *** CORRECTED: Removed backticks ***
                alu_op       = ALU_ADD;    // Effectively ALU result = 0 + imm (needs ALU input A mux)
                mem_read_en  = 1'b0;
                mem_write_en = 1'b0;
                wb_mux_sel   = WB_MUX_ALU;
                branch       = 1'b0;
                jump         = 1'b0;
             end
             OPC_AUIPC: begin
                 reg_write_en = 1'b1;
                 alu_src_b    = ALU_SRC_IMM; // Add immediate to PC
                  // *** CORRECTED: Removed backticks ***
                 alu_op       = ALU_ADD;    // Needs PC as ALU input A
                 mem_read_en  = 1'b0;
                 mem_write_en = 1'b0;
                 wb_mux_sel   = WB_MUX_ALU;
                 branch       = 1'b0;
                 jump         = 1'b0;
             end
            default: begin // Undefined or unsupported opcode
                reg_write_en = 1'b0;
                alu_src_b    = ALU_SRC_REG;
                alu_op       = 4'bxxxx;
                mem_read_en  = 1'b0;
                mem_write_en = 1'b0;
                wb_mux_sel   = WB_MUX_ALU;
                branch       = 1'b0;
                jump         = 1'b0;
            end
        endcase
    end

endmodule

// Hazard Detection Unit (Simplified)
module hazard_unit #(
    parameter XLEN = 32
) (
    // Inputs from ID stage
    input  logic [4:0] rs1_addr_id,
    input  logic [4:0] rs2_addr_id,
    // Inputs from ID/EX register
    input  logic       mem_read_en_ex,
    input  logic [4:0] rd_addr_ex,
    // Inputs from EX/MEM register
    input  logic [4:0] rd_addr_mem,
    input  logic       reg_write_en_mem,
    // Inputs from MEM/WB register
    input  logic [4:0] rd_addr_wb,
    input  logic       reg_write_en_wb,
    // Branch/Jump signals
    input  logic       branch_taken_ex, // Decision made in EX stage

    // Outputs to control pipeline
    output logic       pc_write_en,
    output logic       if_id_write_en,
    output logic       id_ex_bubble_en, // Insert bubble into ID/EX
    // Forwarding controls
    output logic [1:0] forward_a_ex, // 00: ID, 01: MEM, 10: WB
    output logic [1:0] forward_b_ex  // 00: ID, 01: MEM, 10: WB
);

    localparam FWD_ID  = 2'b00;
    localparam FWD_MEM = 2'b01; // Forward from MEM stage (ALU result)
    localparam FWD_WB  = 2'b10; // Forward from WB stage (ALU or Mem data)

    // Default: No hazards, enable writes, no bubbles, no forwarding
    assign pc_write_en     = 1'b1;
    assign if_id_write_en  = 1'b1;
    assign id_ex_bubble_en = 1'b0;
    assign forward_a_ex    = FWD_ID;
    assign forward_b_ex    = FWD_ID;

    // --- Data Hazard Detection ---

    // 1. Load-Use Hazard Detection (Stall)
    // If instruction in EX is LW and its destination matches
    // source registers of instruction in ID, stall.
    logic load_use_hazard;
    assign load_use_hazard = mem_read_en_ex && (rd_addr_ex != 5'b0) &&
                             ((rd_addr_ex == rs1_addr_id) || (rd_addr_ex == rs2_addr_id));

    // --- Forwarding Logic ---
    always_comb begin
        // Default assignments (overridden below if forwarding needed)
        forward_a_ex = FWD_ID;
        forward_b_ex = FWD_ID;

        // EX/MEM Hazard (Forward ALU result from previous instruction)
        if (reg_write_en_mem && (rd_addr_mem != 5'b0)) begin
            if (rd_addr_mem == rs1_addr_id) begin
                forward_a_ex = FWD_MEM;
            end
            if (rd_addr_mem == rs2_addr_id) begin
                forward_b_ex = FWD_MEM;
            end
        end

        // MEM/WB Hazard (Forward ALU result or Load data from instruction before previous)
        // Priority given to EX/MEM hazard, so check if not already forwarded from MEM
        if (reg_write_en_wb && (rd_addr_wb != 5'b0)) begin
            if ((rd_addr_wb == rs1_addr_id) && (forward_a_ex == FWD_ID)) begin
                 // Check if not MEM hazard for same register (rd_addr_mem != rs1_addr_id)
                 // This check prevents forwarding stale data if MEM stage also writes same reg
                 if (!(reg_write_en_mem && (rd_addr_mem != 5'b0) && (rd_addr_mem == rs1_addr_id))) begin
                    forward_a_ex = FWD_WB;
                 end
            end
            if ((rd_addr_wb == rs2_addr_id) && (forward_b_ex == FWD_ID)) begin
                 if (!(reg_write_en_mem && (rd_addr_mem != 5'b0) && (rd_addr_mem == rs2_addr_id))) begin
                    forward_b_ex = FWD_WB;
                 end
            end
        end
    end

    // --- Stall/Bubble Logic ---
    always_comb begin
        if (load_use_hazard) begin
            pc_write_en     = 1'b0; // Stall PC
            if_id_write_en  = 1'b0; // Stall IF/ID register
            id_ex_bubble_en = 1'b1; // Insert bubble into ID/EX
        end else if (branch_taken_ex) begin // Control Hazard
             pc_write_en     = 1'b1; // Allow PC to update to branch target
             if_id_write_en  = 1'b1; // Allow next instruction into IF/ID (could be target)
                                     // Need to flush IF/ID and ID/EX - handled by muxes/clearing regs
             // Bubble insertion/flushing handled implicitly by control signal changes in pipeline stages
        end else begin
            pc_write_en     = 1'b1;
            if_id_write_en  = 1'b1;
            id_ex_bubble_en = 1'b0;
        end
    end

endmodule


// --- Pipeline Registers ---
// (Simplified: only data path signals shown, control signals also needed)

module if_id_reg #(parameter XLEN = 32) (
    input clk, rst_n, write_en,
    input logic [XLEN-1:0] pc_if, instr_if,
    output logic [XLEN-1:0] pc_id, instr_id
);
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc_id <= 0;
            instr_id <= 0; // NOP
        end else if (write_en) begin
            pc_id <= pc_if;
            instr_id <= instr_if;
        end
        // No else: retain value if write_en is low (stall)
    end
endmodule

module id_ex_reg #(parameter XLEN = 32) (
    input clk, rst_n, bubble_en, // bubble_en clears the register
    // Data inputs from ID
    input logic [XLEN-1:0] pc_id, rs1_data_id, rs2_data_id, imm_id,
    input logic [4:0] rs1_addr_id, rs2_addr_id, rd_addr_id,
    // Control inputs from ID
    input logic reg_write_en_id, mem_read_en_id, mem_write_en_id, branch_id, jump_id,
    input logic [1:0] alu_src_b_id, wb_mux_sel_id,
    input logic [3:0] alu_op_id,
    // Data outputs to EX
    output logic [XLEN-1:0] pc_ex, rs1_data_ex, rs2_data_ex, imm_ex,
    output logic [4:0] rs1_addr_ex, rs2_addr_ex, rd_addr_ex,
    // Control outputs to EX
    output logic reg_write_en_ex, mem_read_en_ex, mem_write_en_ex, branch_ex, jump_ex,
    output logic [1:0] alu_src_b_ex, wb_mux_sel_ex,
    output logic [3:0] alu_op_ex
);
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n || bubble_en) begin // Reset or insert bubble (NOP)
            pc_ex <= 0;
            rs1_data_ex <= 0;
            rs2_data_ex <= 0;
            imm_ex <= 0;
            rs1_addr_ex <= 0;
            rs2_addr_ex <= 0;
            rd_addr_ex <= 0;
            // Clear control signals for NOP
            reg_write_en_ex <= 1'b0;
            mem_read_en_ex  <= 1'b0;
            mem_write_en_ex <= 1'b0;
            branch_ex       <= 1'b0;
            jump_ex         <= 1'b0;
            alu_src_b_ex    <= 2'b00;
            wb_mux_sel_ex   <= 2'b00;
            alu_op_ex       <= 4'b0000; // Default to ADD for NOP safety? Or specific NOP op
        end else begin
            pc_ex <= pc_id;
            rs1_data_ex <= rs1_data_id;
            rs2_data_ex <= rs2_data_id;
            imm_ex <= imm_id;
            rs1_addr_ex <= rs1_addr_id;
            rs2_addr_ex <= rs2_addr_id;
            rd_addr_ex <= rd_addr_id;
            // Pass control signals
            reg_write_en_ex <= reg_write_en_id;
            mem_read_en_ex  <= mem_read_en_id;
            mem_write_en_ex <= mem_write_en_id;
            branch_ex       <= branch_id;
            jump_ex         <= jump_id;
            alu_src_b_ex    <= alu_src_b_id;
            wb_mux_sel_ex   <= wb_mux_sel_id;
            alu_op_ex       <= alu_op_id;
        end
    end
endmodule

module ex_mem_reg #(parameter XLEN = 32) (
    input clk, rst_n,
    // Data inputs from EX
    input logic [XLEN-1:0] alu_result_ex, rs2_data_ex, pc_plus_4_ex, // rs2_data needed for SW
    input logic [4:0] rd_addr_ex,
    input logic zero_flag_ex, // ALU zero flag for branches
    // Control inputs from EX
    input logic reg_write_en_ex, mem_read_en_ex, mem_write_en_ex, branch_ex, jump_ex,
    input logic [1:0] wb_mux_sel_ex,
    // Data outputs to MEM
    output logic [XLEN-1:0] alu_result_mem, rs2_data_mem, pc_plus_4_mem,
    output logic [4:0] rd_addr_mem,
    output logic zero_flag_mem,
    // Control outputs to MEM
    output logic reg_write_en_mem, mem_read_en_mem, mem_write_en_mem, branch_mem, jump_mem,
    output logic [1:0] wb_mux_sel_mem
);
     always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            alu_result_mem <= 0;
            rs2_data_mem <= 0;
            pc_plus_4_mem <= 0;
            rd_addr_mem <= 0;
            zero_flag_mem <= 0;
            // Clear control signals
            reg_write_en_mem <= 1'b0;
            mem_read_en_mem  <= 1'b0;
            mem_write_en_mem <= 1'b0;
            branch_mem       <= 1'b0;
            jump_mem         <= 1'b0;
            wb_mux_sel_mem   <= 2'b00;
        end else begin
            alu_result_mem <= alu_result_ex;
            rs2_data_mem <= rs2_data_ex;
            pc_plus_4_mem <= pc_plus_4_ex;
            rd_addr_mem <= rd_addr_ex;
            zero_flag_mem <= zero_flag_ex;
            // Pass control signals
            reg_write_en_mem <= reg_write_en_ex;
            mem_read_en_mem  <= mem_read_en_ex;
            mem_write_en_mem <= mem_write_en_ex;
            branch_mem       <= branch_ex; // Pass branch type
            jump_mem         <= jump_ex;   // Pass jump type
            wb_mux_sel_mem   <= wb_mux_sel_ex;
        end
    end
endmodule

module mem_wb_reg #(parameter XLEN = 32) (
    input clk, rst_n,
    // Data inputs from MEM
    input logic [XLEN-1:0] mem_read_data_mem, alu_result_mem, pc_plus_4_mem,
    input logic [4:0] rd_addr_mem,
    // Control inputs from MEM
    input logic reg_write_en_mem,
    input logic [1:0] wb_mux_sel_mem,
    // Data outputs to WB
    output logic [XLEN-1:0] mem_read_data_wb, alu_result_wb, pc_plus_4_wb,
    output logic [4:0] rd_addr_wb,
    // Control outputs to WB
    output logic reg_write_en_wb,
    output logic [1:0] wb_mux_sel_wb
);
     always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_read_data_wb <= 0;
            alu_result_wb <= 0;
            pc_plus_4_wb <= 0;
            rd_addr_wb <= 0;
            reg_write_en_wb <= 1'b0;
            wb_mux_sel_wb <= 2'b00;
        end else begin
            mem_read_data_wb <= mem_read_data_mem;
            alu_result_wb <= alu_result_mem;
            pc_plus_4_wb <= pc_plus_4_mem;
            rd_addr_wb <= rd_addr_mem;
            reg_write_en_wb <= reg_write_en_mem;
            wb_mux_sel_wb <= wb_mux_sel_mem;
        end
    end
endmodule


// --- Top Level Module ---
module riscv_pipelined_core #(
    parameter XLEN = 32,
    parameter START_ADDR = 32'h00000000
) (
    input  logic clk,
    input  logic rst_n,
    // Instruction Memory Interface
    output logic [XLEN-1:0] imem_addr,
    input  logic [XLEN-1:0] imem_rdata,
    // Data Memory Interface
    output logic [XLEN-1:0] dmem_addr,
    output logic [XLEN-1:0] dmem_wdata,
    output logic            dmem_wen, // Write enable
    input  logic [XLEN-1:0] dmem_rdata
);

    // --- Signals ---
    // PC and IF Stage
    logic [XLEN-1:0] pc_if;
    logic [XLEN-1:0] pc_next_if;
    logic [XLEN-1:0] pc_plus_4_if;
    logic [XLEN-1:0] instr_if;
    logic            pc_write_en; // From Hazard Unit
    logic            if_id_write_en; // From Hazard Unit

    // IF/ID Register Outputs
    logic [XLEN-1:0] pc_id;
    logic [XLEN-1:0] instr_id;

    // ID Stage
    logic [XLEN-1:0] rs1_data_id;
    logic [XLEN-1:0] rs2_data_id;
    logic [XLEN-1:0] imm_id;
    logic [4:0]      rs1_addr_id;
    logic [4:0]      rs2_addr_id;
    logic [4:0]      rd_addr_id;
    logic [6:0]      opcode_id;
    logic [2:0]      funct3_id;
    logic            funct7b5_id;
    // Control Signals (ID)
    logic       reg_write_en_id;
    logic [1:0] alu_src_b_id;
    logic [3:0] alu_op_id;
    logic       mem_read_en_id;
    logic       mem_write_en_id;
    logic [1:0] wb_mux_sel_id;
    logic       branch_id;
    logic       jump_id;
    logic       id_ex_bubble_en; // From Hazard Unit

    // ID/EX Register Outputs
    logic [XLEN-1:0] pc_ex;
    logic [XLEN-1:0] rs1_data_ex_pre_fwd; // Before forwarding mux
    logic [XLEN-1:0] rs2_data_ex_pre_fwd; // Before forwarding mux
    logic [XLEN-1:0] imm_ex;
    logic [4:0]      rs1_addr_ex;
    logic [4:0]      rs2_addr_ex;
    logic [4:0]      rd_addr_ex;
    logic            reg_write_en_ex;
    logic [1:0]      alu_src_b_ex;
    logic [3:0]      alu_op_ex;
    logic            mem_read_en_ex;
    logic            mem_write_en_ex;
    logic [1:0]      wb_mux_sel_ex;
    logic            branch_ex;
    logic            jump_ex;

    // EX Stage
    logic [XLEN-1:0] alu_operand_a;
    logic [XLEN-1:0] alu_operand_b;
    logic [XLEN-1:0] alu_result_ex;
    logic            zero_flag_ex;
    logic [XLEN-1:0] branch_target_ex;
    logic [XLEN-1:0] jump_target_ex; // For JAL/JALR
    logic            branch_taken_ex;
    logic [XLEN-1:0] pc_plus_4_ex;
    logic [1:0]      forward_a_ex; // From Hazard Unit
    logic [1:0]      forward_b_ex; // From Hazard Unit

    // EX/MEM Register Outputs
    logic [XLEN-1:0] alu_result_mem;
    logic [XLEN-1:0] rs2_data_mem; // For SW
    logic [XLEN-1:0] pc_plus_4_mem; // For JAL/JALR writeback
    logic [4:0]      rd_addr_mem;
    logic            zero_flag_mem;
    logic            reg_write_en_mem;
    logic            mem_read_en_mem;
    logic            mem_write_en_mem;
    logic            branch_mem; // Not used directly in MEM, passed for hazard unit?
    logic            jump_mem;   // Not used directly in MEM
    logic [1:0]      wb_mux_sel_mem;

    // MEM Stage
    logic [XLEN-1:0] mem_read_data_mem;

    // MEM/WB Register Outputs
    logic [XLEN-1:0] mem_read_data_wb;
    logic [XLEN-1:0] alu_result_wb;
    logic [XLEN-1:0] pc_plus_4_wb;
    logic [4:0]      rd_addr_wb;
    logic            reg_write_en_wb;
    logic [1:0]      wb_mux_sel_wb;

    // WB Stage
    logic [XLEN-1:0] rd_data_wb;


    // --- Stage Implementations ---

    // IF Stage
    assign pc_plus_4_if = pc_if + 4;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc_if <= START_ADDR;
        end else if (pc_write_en) begin
             pc_if <= pc_next_if;
        end
        // No else: Retain PC value during stall
    end

    assign imem_addr = pc_if;
    assign instr_if = imem_rdata; // Assuming synchronous memory

    // PC Mux Logic - Selects next PC based on branch/jump decisions in EX
    // Note: This uses signals from EX stage, introducing latency. More advanced cores might predict earlier.
    assign pc_next_if = branch_taken_ex ? branch_target_ex :
                        (jump_ex && (opcode_id == 7'b1101111)) ? jump_target_ex : // JAL target calc in EX (pc_ex + imm_ex)
                        (jump_ex && (opcode_id == 7'b1100111)) ? alu_result_ex :   // JALR target is ALU result (rs1_data + imm) calculated in EX
                        pc_plus_4_if; // Default: PC + 4


    // IF/ID Register
    if_id_reg #(XLEN) if_id_reg_inst (
        .clk(clk), .rst_n(rst_n), .write_en(if_id_write_en),
        .pc_if(pc_if), .instr_if(instr_if),
        .pc_id(pc_id), .instr_id(instr_id)
    );

    // ID Stage
    assign rs1_addr_id = instr_id[19:15];
    assign rs2_addr_id = instr_id[24:20];
    assign rd_addr_id  = instr_id[11:7];
    assign opcode_id   = instr_id[6:0];
    assign funct3_id   = instr_id[14:12];
    assign funct7b5_id = instr_id[30];

    reg_file #(XLEN) reg_file_inst (
        .clk(clk), .rst_n(rst_n),
        .we_wb(reg_write_en_wb),
        .rs1_addr_id(rs1_addr_id),
        .rs2_addr_id(rs2_addr_id),
        .rd_addr_wb(rd_addr_wb),
        .rd_data_wb(rd_data_wb),
        .rs1_data_id(rs1_data_id),
        .rs2_data_id(rs2_data_id)
    );

    imm_gen #(XLEN) imm_gen_inst (
        .instr_id(instr_id),
        .imm_id(imm_id)
    );

    control_unit control_unit_inst (
        .opcode(opcode_id),
        .funct3(funct3_id),
        .funct7b5(funct7b5_id),
        .reg_write_en(reg_write_en_id),
        .alu_src_b(alu_src_b_id),
        .alu_op(alu_op_id),
        .mem_read_en(mem_read_en_id),
        .mem_write_en(mem_write_en_id),
        .wb_mux_sel(wb_mux_sel_id),
        .branch(branch_id),
        .jump(jump_id)
    );

    // ID/EX Register
    id_ex_reg #(XLEN) id_ex_reg_inst (
         .clk(clk), .rst_n(rst_n), .bubble_en(id_ex_bubble_en || branch_taken_ex), // Bubble on stall or flush
         // Data inputs from ID
         .pc_id(pc_id), .rs1_data_id(rs1_data_id), .rs2_data_id(rs2_data_id), .imm_id(imm_id),
         .rs1_addr_id(rs1_addr_id), .rs2_addr_id(rs2_addr_id), .rd_addr_id(rd_addr_id),
         // Control inputs from ID
         .reg_write_en_id(reg_write_en_id), .mem_read_en_id(mem_read_en_id), .mem_write_en_id(mem_write_en_id),
         .branch_id(branch_id), .jump_id(jump_id),
         .alu_src_b_id(alu_src_b_id), .wb_mux_sel_id(wb_mux_sel_id),
         .alu_op_id(alu_op_id),
         // Data outputs to EX
         .pc_ex(pc_ex), .rs1_data_ex(rs1_data_ex_pre_fwd), .rs2_data_ex(rs2_data_ex_pre_fwd), .imm_ex(imm_ex),
         .rs1_addr_ex(rs1_addr_ex), .rs2_addr_ex(rs2_addr_ex), .rd_addr_ex(rd_addr_ex),
         // Control outputs to EX
         .reg_write_en_ex(reg_write_en_ex), .mem_read_en_ex(mem_read_en_ex), .mem_write_en_ex(mem_write_en_ex),
         .branch_ex(branch_ex), .jump_ex(jump_ex),
         .alu_src_b_ex(alu_src_b_ex), .wb_mux_sel_ex(wb_mux_sel_ex),
         .alu_op_ex(alu_op_ex)
    );

    // EX Stage
    assign pc_plus_4_ex = pc_ex + 4; // Needed for JAL/JALR link address

    // Forwarding Muxes for ALU inputs
    assign alu_operand_a = (forward_a_ex == 2'b00) ? rs1_data_ex_pre_fwd : // From ID/EX
                           (forward_a_ex == 2'b01) ? alu_result_mem :      // From EX/MEM (ALU result)
                           (forward_a_ex == 2'b10) ? rd_data_wb :          // From MEM/WB (ALU or Mem data)
                           rs1_data_ex_pre_fwd; // Default

    logic [XLEN-1:0] rs2_data_ex_fwd; // rs2 might be forwarded
    assign rs2_data_ex_fwd = (forward_b_ex == 2'b00) ? rs2_data_ex_pre_fwd : // From ID/EX
                             (forward_b_ex == 2'b01) ? alu_result_mem :      // From EX/MEM (ALU result)
                             (forward_b_ex == 2'b10) ? rd_data_wb :          // From MEM/WB (ALU or Mem data)
                             rs2_data_ex_pre_fwd; // Default

    // ALU Operand B Mux
    assign alu_operand_b = (alu_src_b_ex == 2'b00) ? rs2_data_ex_fwd : // Register source (potentially forwarded)
                           (alu_src_b_ex == 2'b01) ? imm_ex :          // Immediate source
                           {XLEN{1'bx}}; // Undefined source


    riscv_alu #(XLEN) alu_inst (
        // Adjust operand A based on instruction type if needed (e.g., LUI, AUIPC)
        // Simple approach: Assume ALU gets correct inputs via muxes controlled elsewhere or implicitly
        .operand_a( (alu_op_ex == ALU_ADD && wb_mux_sel_ex == WB_MUX_ALU && alu_src_b_ex == ALU_SRC_IMM && opcode_id == 7'b0110111) ? 32'b0 : // LUI: Use 0 as operand A
                     (alu_op_ex == ALU_ADD && wb_mux_sel_ex == WB_MUX_ALU && alu_src_b_ex == ALU_SRC_IMM && opcode_id == 7'b0010111) ? pc_ex :   // AUIPC: Use PC as operand A
                     alu_operand_a ), // Default forwarded value
        .operand_b(alu_operand_b),
        .alu_op(alu_op_ex),
        .alu_result(alu_result_ex)
    );

    assign zero_flag_ex = (alu_result_ex == {XLEN{1'b0}});

    // Branch/Jump Target Calculation
    assign branch_target_ex = pc_ex + imm_ex; // B-type immediate is signed offset
    assign jump_target_ex   = pc_ex + imm_ex; // J-type immediate is signed offset (for JAL)
                                             // JALR target is alu_result_ex (rs1 + imm)

    // Branch Taken Logic (Simplified BEQ example)
    // Assumes alu_op for branch was SUB. Need specific check based on funct3 for BEQ/BNE etc.
    // This logic should ideally use funct3 from EX stage controls
    assign branch_taken_ex = branch_ex && zero_flag_ex; // Taken if branch instruction and zero flag is set (for BEQ)


    // EX/MEM Register
    ex_mem_reg #(XLEN) ex_mem_reg_inst (
         .clk(clk), .rst_n(rst_n),
         // Data inputs from EX
         .alu_result_ex(alu_result_ex), .rs2_data_ex(rs2_data_ex_fwd), .pc_plus_4_ex(pc_plus_4_ex),
         .rd_addr_ex(rd_addr_ex),
         .zero_flag_ex(zero_flag_ex),
         // Control inputs from EX
         .reg_write_en_ex(reg_write_en_ex), .mem_read_en_ex(mem_read_en_ex), .mem_write_en_ex(mem_write_en_ex),
         .branch_ex(branch_ex), .jump_ex(jump_ex), .wb_mux_sel_ex(wb_mux_sel_ex),
         // Data outputs to MEM
         .alu_result_mem(alu_result_mem), .rs2_data_mem(rs2_data_mem), .pc_plus_4_mem(pc_plus_4_mem),
         .rd_addr_mem(rd_addr_mem), .zero_flag_mem(zero_flag_mem),
         // Control outputs to MEM
         .reg_write_en_mem(reg_write_en_mem), .mem_read_en_mem(mem_read_en_mem), .mem_write_en_mem(mem_write_en_mem),
         .branch_mem(branch_mem), .jump_mem(jump_mem), .wb_mux_sel_mem(wb_mux_sel_mem)
    );

    // MEM Stage
    assign dmem_addr = alu_result_mem; // Address calculated in EX stage
    assign dmem_wdata = rs2_data_mem;  // Data to write comes from rs2 (forwarded)
    assign dmem_wen = mem_write_en_mem;
    assign mem_read_data_mem = dmem_rdata; // Assuming synchronous memory

    // MEM/WB Register
    mem_wb_reg #(XLEN) mem_wb_reg_inst (
         .clk(clk), .rst_n(rst_n),
         // Data inputs from MEM
         .mem_read_data_mem(mem_read_data_mem), .alu_result_mem(alu_result_mem), .pc_plus_4_mem(pc_plus_4_mem),
         .rd_addr_mem(rd_addr_mem),
         // Control inputs from MEM
         .reg_write_en_mem(reg_write_en_mem), .wb_mux_sel_mem(wb_mux_sel_mem),
         // Data outputs to WB
         .mem_read_data_wb(mem_read_data_wb), .alu_result_wb(alu_result_wb), .pc_plus_4_wb(pc_plus_4_wb),
         .rd_addr_wb(rd_addr_wb),
         // Control outputs to WB
         .reg_write_en_wb(reg_write_en_wb), .wb_mux_sel_wb(wb_mux_sel_wb)
    );

    // WB Stage
    assign rd_data_wb = (wb_mux_sel_wb == 2'b00) ? alu_result_wb :    // ALU result
                        (wb_mux_sel_wb == 2'b01) ? mem_read_data_wb : // Data from memory
                        (wb_mux_sel_wb == 2'b10) ? pc_plus_4_wb :     // PC+4 for JAL/JALR
                        {XLEN{1'bx}}; // Undefined


    // Hazard Unit
    hazard_unit #(XLEN) hazard_unit_inst (
        // Inputs from ID stage
        .rs1_addr_id(rs1_addr_id),
        .rs2_addr_id(rs2_addr_id),
        // Inputs from ID/EX register
        .mem_read_en_ex(mem_read_en_ex), // Control signal from ID passed to EX
        .rd_addr_ex(rd_addr_ex),         // Destination register from ID passed to EX
        // Inputs from EX/MEM register
        .rd_addr_mem(rd_addr_mem),
        .reg_write_en_mem(reg_write_en_mem),
        // Inputs from MEM/WB register
        .rd_addr_wb(rd_addr_wb),
        .reg_write_en_wb(reg_write_en_wb),
        // Branch/Jump signals
        .branch_taken_ex(branch_taken_ex),

        // Outputs to control pipeline
        .pc_write_en(pc_write_en),
        .if_id_write_en(if_id_write_en),
        .id_ex_bubble_en(id_ex_bubble_en),
        // Forwarding controls
        .forward_a_ex(forward_a_ex),
        .forward_b_ex(forward_b_ex)
    );

endmodule
