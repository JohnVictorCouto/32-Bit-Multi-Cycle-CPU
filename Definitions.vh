`ifndef DEFINITIONS_VH
`define DEFINITIONS_VH

// Width definitions
`define DATA_WIDTH   32   // Data width in bits
`define ADDR_WIDTH   32   // Address width in bits
`define INST_WIDTH   32
`define NUM_REGISTER 32

// Memory size
`define MEM_SIZE (64'd1 << `ADDR_WIDTH) // Total number of memory locations

// Instruction field widths
`define OPCODE  7
`define FUNCT_3 3
`define FUNCT_7 7

// ============================================================================
// RISC-V Base Instruction Set Opcodes (RV32I)
// ============================================================================
`define OP_LUI     7'b0110111 // Load Upper Immediate
`define OP_AUIPC   7'b0010111 // Add Upper Immediate to PC
`define OP_JAL     7'b1101111 // Jump and Link
`define OP_JALR    7'b1100111 // Jump and Link Register
`define OP_BRANCH  7'b1100011 // Branch Instructions (BEQ, BNE, BLT, BGE, BLTU, BGEU)
`define OP_LOAD    7'b0000011 // Load Instructions (LB, LH, LW, LBU, LHU)
`define OP_STORE   7'b0100011 // Store Instructions (SB, SH, SW)
`define OP_ALU     7'b0110011 // ALU Register Instructions (ADD, SUB, AND, OR, XOR, etc.)
`define OP_ALUI    7'b0010011 // ALU Immediate Instructions (ADDI, ANDI, ORI, XORI, etc.)
`define OP_FENCE   7'b0001111 // Fence (FENCE, FENCE.I)
`define OP_SYSTEM  7'b1110011 // System Instructions (ECALL, EBREAK, CSR*)

// ============================================================================
// Funct7 Definitions (Para distinguir ADD/SUB e SRL/SRA/SRAI)
// ============================================================================
`define FUNCT7_DEFAULT 7'b0000000 // ADD, SLL, SLT, SLTU, XOR, SRL, OR, AND, SLLI, SRLI
`define FUNCT7_ALT     7'b0100000 // SUB, SRA, SRAI
`define FUNCT7_MULDIV  7'b0000001 // M-extension: MUL, DIV, REM, etc.
`define FUNCT7_ZBA     7'b0010000 // SH1ADD, SH2ADD, SH3ADD
`define FUNCT7_ZBB_LOGICAL 7'b0100000 // ANDN, ORN, XNOR
`define FUNCT7_ZBB_MINMAX 7'b0000101 // MIN, MINU, MAX, MAXU
`define FUNCT7_ZBB_ROT 7'b0110000 // ROL, ROR
`define FUNCT7_ZBS_CLEAR_EXTRACT 7'b0100100 // BCLR, BEXT
`define FUNCT7_ZBS_INVERT 7'b0110100 // BINV
`define FUNCT7_ZBS_SET 7'b0000100 // BSET, ZEXT.H

// ============================================================================
// Funct3 Definitions: ALU & ALU Immediate Instructions
// ============================================================================
`define FUNCT3_ADD_SUB 3'b000 // ADD, SUB, ADDI
`define FUNCT3_SLL     3'b001 // SLL, SLLI
`define FUNCT3_SLT     3'b010 // SLT, SLTI
`define FUNCT3_SLTU    3'b011 // SLTU, SLTIU
`define FUNCT3_XOR     3'b100 // XOR, XORI
`define FUNCT3_SRL_SRA 3'b101 // SRL, SRA, SRLI, SRAI
`define FUNCT3_OR      3'b110 // OR, ORI
`define FUNCT3_AND     3'b111 // AND, ANDI
`define FUNCT3_MUL     3'b000 // MUL
`define FUNCT3_MULH    3'b001 // MULH
`define FUNCT3_MULHSU  3'b010 // MULHSU
`define FUNCT3_MULHU   3'b011 // MULHU
`define FUNCT3_DIV     3'b100 // DIV
`define FUNCT3_DIVU    3'b101 // DIVU
`define FUNCT3_REM     3'b110 // REM
`define FUNCT3_REMU    3'b111 // REMU

// ============================================================================
// Funct3 Definitions: Load & Store Instructions
// ============================================================================
`define LOAD_LB        3'b000 // Load Byte (signed)
`define LOAD_LH        3'b001 // Load Halfword (signed)
`define LOAD_LW        3'b010 // Load Word
`define LOAD_LBU       3'b100 // Load Byte Unsigned
`define LOAD_LHU       3'b101 // Load Halfword Unsigned

`define STORE_SB       3'b000 // Store Byte
`define STORE_SH       3'b001 // Store Halfword
`define STORE_SW       3'b010 // Store Word

// ============================================================================
// Funct3 Definitions: Branch Instructions
// ============================================================================
`define BRANCH_BEQ     3'b000 // Branch Equal
`define BRANCH_BNE     3'b001 // Branch Not Equal
`define BRANCH_BLT     3'b100 // Branch Less Than (signed)
`define BRANCH_BGE     3'b101 // Branch Greater Than Or Equal (signed)
`define BRANCH_BLTU    3'b110 // Branch Less Than Unsigned
`define BRANCH_BGEU    3'b111 // Branch Greater Than Or Equal Unsigned

// ============================================================================
// Funct3 & Funct12 Definitions: Fence & System (Zifencei / Zicsr / Priv)
// ============================================================================
`define FUNCT3_FENCE   3'b000 // FENCE
`define FUNCT3_FENCE_I 3'b001 // FENCE.I

`define FUNCT3_PRIV    3'b000 // ECALL, EBREAK
`define FUNCT3_CSRRW   3'b001 // CSR Read/Write
`define FUNCT3_CSRRS   3'b010 // CSR Read and Set
`define FUNCT3_CSRRC   3'b011 // CSR Read and Clear
`define FUNCT3_CSRRWI  3'b101 // CSR Read/Write Immediate
`define FUNCT3_CSRRSI  3'b110 // CSR Read and Set Immediate
`define FUNCT3_CSRRCI  3'b111 // CSR Read and Clear Immediate

`define FUNCT12_ECALL  12'h000 // Environment Call
`define FUNCT12_EBREAK 12'h001 // Environment Break

// ============================================================================
// RISC-V ALU Operations (Internal Control Signals)
// ============================================================================
`define OP_ALU_NOP     6'b000000 
`define OP_ALU_ADD     6'b011001 // Add (ADD, ADDI, AUIPC, LOAD, STORE, JAL, JALR)
`define OP_ALU_SUB     6'b011011 // Subtract (SUB, BRANCH)
`define OP_ALU_AND     6'b011101 // Bitwise AND (AND, ANDI)
`define OP_ALU_OR      6'b011111 // Bitwise OR (OR, ORI)
`define OP_ALU_XOR     6'b100001 // Bitwise XOR (XOR, XORI)
`define OP_ALU_SLT     6'b100011 // Set Less Than signed (SLT, SLTI)
`define OP_ALU_SLTU    6'b100101 // Set Less Than unsigned (SLTU, SLTIU)
`define OP_ALU_SLL     6'b100111 // Shift Left Logical (SLL, SLLI)
`define OP_ALU_SRL     6'b101001 // Shift Right Logical (SRL, SRLI)
`define OP_ALU_SRA     6'b101011 // Shift Right Arithmetic (SRA, SRAI)
`define OP_ALU_MUL     6'b101101 // Multiply (MUL)
`define OP_ALU_MULH    6'b110000 // Multiply high signed-signed (MULH)
`define OP_ALU_MULHSU  6'b110001 // Multiply high signed-unsigned (MULHSU)
`define OP_ALU_MULHU   6'b110010 // Multiply high unsigned-unsigned (MULHU)
`define OP_ALU_DIV     6'b110011 // Divide (DIV)
`define OP_ALU_DIVU    6'b110100 // Divide unsigned (DIVU)
`define OP_ALU_REM     6'b110101 // Remainder (REM)
`define OP_ALU_REMU    6'b110110 // Remainder unsigned (REMU)
`define OP_ALU_PASS_B  6'b110111 // Pass Operand B directly (LUI)

// RV32 Zba/Zbb/Zbs operations
`define OP_ALU_ANDN    8'h40
`define OP_ALU_ORN     8'h41
`define OP_ALU_XNOR    8'h42
`define OP_ALU_CLZ     8'h43
`define OP_ALU_CTZ     8'h44
`define OP_ALU_CPOP    8'h45
`define OP_ALU_MIN     8'h46
`define OP_ALU_MINU    8'h47
`define OP_ALU_MAX     8'h48
`define OP_ALU_MAXU    8'h49
`define OP_ALU_ROL     8'h4a
`define OP_ALU_ROR     8'h4b
`define OP_ALU_ORCB    8'h4c
`define OP_ALU_REV8    8'h4d
`define OP_ALU_SEXTB   8'h4e
`define OP_ALU_SEXTH   8'h4f
`define OP_ALU_ZEXTH   8'h50
`define OP_ALU_BCLR    8'h51
`define OP_ALU_BEXT    8'h52
`define OP_ALU_BINV    8'h53
`define OP_ALU_BSET    8'h54
`define OP_ALU_SH1ADD  8'h55
`define OP_ALU_SH2ADD  8'h56
`define OP_ALU_SH3ADD  8'h57

`endif // DEFINITIONS_VH
