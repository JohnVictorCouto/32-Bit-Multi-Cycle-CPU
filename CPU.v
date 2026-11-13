`timescale 1ns/1ps

`include "Definitions.vh"

module CPU #(
    parameter integer IMEM_WORDS = 256,
    parameter integer DMEM_BYTES = 1024,
    parameter [31:0] RESET_PC = 32'h00000000,
    parameter IMEM_INIT_FILE = "",
    parameter DMEM_INIT_FILE = ""
) (
    input wire clk,
    input wire reset,
    input wire irq_software,
    input wire irq_timer,
    input wire irq_external,
    output reg [31:0] pc,
    output reg trap_taken,
    output reg [31:0] last_trap_cause
);

localparam [3:0] ST_FETCH   = 4'd0;
localparam [3:0] ST_DECODE  = 4'd1;
localparam [3:0] ST_EXEC_R  = 4'd2;
localparam [3:0] ST_EXEC_I  = 4'd3;
localparam [3:0] ST_EXEC_U  = 4'd4;
localparam [3:0] ST_ADDR    = 4'd5;
localparam [3:0] ST_LOAD    = 4'd6;
localparam [3:0] ST_STORE   = 4'd7;
localparam [3:0] ST_BRANCH  = 4'd8;
localparam [3:0] ST_JUMP    = 4'd9;
localparam [3:0] ST_CSR     = 4'd10;
localparam [3:0] ST_WB      = 4'd11;
localparam [3:0] ST_TRAP    = 4'd12;
localparam [3:0] ST_MRET    = 4'd13;

localparam [31:0] CAUSE_INSTRUCTION_MISALIGNED = 32'd0;
localparam [31:0] CAUSE_INSTRUCTION_ACCESS    = 32'd1;
localparam [31:0] CAUSE_ILLEGAL_INSTRUCTION   = 32'd2;
localparam [31:0] CAUSE_BREAKPOINT            = 32'd3;
localparam [31:0] CAUSE_LOAD_MISALIGNED       = 32'd4;
localparam [31:0] CAUSE_LOAD_ACCESS           = 32'd5;
localparam [31:0] CAUSE_STORE_MISALIGNED      = 32'd6;
localparam [31:0] CAUSE_STORE_ACCESS          = 32'd7;
localparam [31:0] CAUSE_MACHINE_ECALL          = 32'd11;
localparam [31:0] CAUSE_MACHINE_SOFTWARE_IRQ   = 32'h80000003;
localparam [31:0] CAUSE_MACHINE_TIMER_IRQ      = 32'h80000007;
localparam [31:0] CAUSE_MACHINE_EXTERNAL_IRQ   = 32'h8000000b;

localparam [11:0] CSR_MSTATUS  = 12'h300;
localparam [11:0] CSR_MISA     = 12'h301;
localparam [11:0] CSR_MIE      = 12'h304;
localparam [11:0] CSR_MTVEC    = 12'h305;
localparam [11:0] CSR_MSCRATCH = 12'h340;
localparam [11:0] CSR_MEPC     = 12'h341;
localparam [11:0] CSR_MCAUSE   = 12'h342;
localparam [11:0] CSR_MTVAL    = 12'h343;
localparam [11:0] CSR_MIP      = 12'h344;
localparam [11:0] CSR_MCYCLE   = 12'hb00;
localparam [11:0] CSR_MINSTRET = 12'hb02;
localparam [11:0] CSR_MCYCLEH  = 12'hb80;
localparam [11:0] CSR_MINSTRETH = 12'hb82;
localparam [11:0] CSR_CYCLE    = 12'hc00;
localparam [11:0] CSR_TIME     = 12'hc01;
localparam [11:0] CSR_INSTRET  = 12'hc02;
localparam [11:0] CSR_CYCLEH   = 12'hc80;
localparam [11:0] CSR_TIMEH    = 12'hc81;
localparam [11:0] CSR_INSTRETH = 12'hc82;
localparam [11:0] CSR_MVENDORID = 12'hf11;
localparam [11:0] CSR_MARCHID   = 12'hf12;
localparam [11:0] CSR_MIMPID    = 12'hf13;
localparam [11:0] CSR_MHARTID   = 12'hf14;

reg [3:0] state;

reg [31:0] instruction;
reg [31:0] instruction_pc;
reg [31:0] operand_a;
reg [31:0] operand_b;
reg [31:0] address_register;
reg [31:0] writeback_data;
reg [4:0] writeback_register;
reg writeback_valid;

reg [31:0] pending_cause;
reg [31:0] pending_tval;
reg [31:0] pending_epc;

reg [31:0] csr_mstatus;
reg [31:0] csr_mie;
reg [31:0] csr_mtvec;
reg [31:0] csr_mscratch;
reg [31:0] csr_mepc;
reg [31:0] csr_mcause;
reg [31:0] csr_mtval;
reg [63:0] csr_mcycle;
reg [63:0] csr_minstret;

reg [31:0] computed_value;
reg [31:0] csr_old_value;
reg [31:0] csr_source_value;
reg [31:0] csr_new_value;
reg [31:0] memory_value;
reg csr_write_requested;
reg [7:0] alu_operation;
reg [31:0] alu_input_a;
reg [31:0] alu_input_b;

wire [31:0] instruction_word;
wire [31:0] register_read_data1;
wire [31:0] register_read_data2;
wire [31:0] data_read_word;
wire [31:0] alu_result;
wire branch_condition;
wire [31:0] immediate_i;
wire [31:0] immediate_s;
wire [31:0] immediate_b;
wire [31:0] immediate_u;
wire [31:0] immediate_j;
wire register_write_enable;
wire data_write_enable;
wire [1:0] data_write_size;
wire decode_illegal;
wire decode_r_type;
wire decode_i_type;
wire decode_u_type;
wire decode_load;
wire decode_store;
wire decode_branch;
wire decode_jal;
wire decode_jalr;
wire decode_fence;
wire decode_csr;
wire decode_ecall;
wire decode_ebreak;
wire decode_mret;

wire [31:0] interrupt_pending = {
    20'b0, irq_external, 3'b0, irq_timer, 3'b0, irq_software, 3'b0
};

wire store_byte_valid =
    (instruction[14:12] == `STORE_SB) && (address_register < DMEM_BYTES);
wire store_half_valid =
    (instruction[14:12] == `STORE_SH) && (address_register[0] == 1'b0) &&
    (address_register < DMEM_BYTES) && ((DMEM_BYTES - address_register) >= 2);
wire store_word_valid =
    (instruction[14:12] == `STORE_SW) && (address_register[1:0] == 2'b00) &&
    (address_register < DMEM_BYTES) && ((DMEM_BYTES - address_register) >= 4);

assign register_write_enable = (state == ST_WB) && writeback_valid;
assign data_write_enable = !reset && (state == ST_STORE) &&
                           (store_byte_valid || store_half_valid || store_word_valid);
assign data_write_size = (instruction[14:12] == `STORE_SW) ? 2'd2 :
                         (instruction[14:12] == `STORE_SH) ? 2'd1 : 2'd0;

InstructionMemory #(
    .WORDS(IMEM_WORDS),
    .INIT_FILE(IMEM_INIT_FILE)
) imem (
    .address(pc),
    .instruction(instruction_word)
);

DataMemory #(
    .BYTES(DMEM_BYTES),
    .INIT_FILE(DMEM_INIT_FILE)
) dmem (
    .clk(clk),
    .address(address_register),
    .write_data(operand_b),
    .write_size(data_write_size),
    .write_enable(data_write_enable),
    .read_word(data_read_word)
);

RegisterFile rf (
    .clk(clk),
    .reset(reset),
    .read_address1(instruction[19:15]),
    .read_address2(instruction[24:20]),
    .read_data1(register_read_data1),
    .read_data2(register_read_data2),
    .write_enable(register_write_enable),
    .write_address(writeback_register),
    .write_data(writeback_data)
);

ALU alu (
    .operand_a(alu_input_a),
    .operand_b(alu_input_b),
    .operation(alu_operation),
    .result(alu_result)
);

Decoder decoder (
    .instruction(instruction),
    .illegal_instruction(decode_illegal),
    .is_r_type(decode_r_type),
    .is_i_type(decode_i_type),
    .is_u_type(decode_u_type),
    .is_load(decode_load),
    .is_store(decode_store),
    .is_branch(decode_branch),
    .is_jal(decode_jal),
    .is_jalr(decode_jalr),
    .is_fence(decode_fence),
    .is_csr(decode_csr),
    .is_ecall(decode_ecall),
    .is_ebreak(decode_ebreak),
    .is_mret(decode_mret)
);

SignalExtensionUnit signal_extension_unit (
    .instruction(instruction),
    .immediate_i(immediate_i),
    .immediate_s(immediate_s),
    .immediate_b(immediate_b),
    .immediate_u(immediate_u),
    .immediate_j(immediate_j)
);

BranchUnit branch_unit (
    .funct3(instruction[14:12]),
    .operand_a(operand_a),
    .operand_b(operand_b),
    .branch_taken(branch_condition)
);

always @* begin
    alu_operation = `OP_ALU_NOP;
    alu_input_a = operand_a;
    alu_input_b = operand_b;

    case (state)
        ST_EXEC_R, ST_EXEC_I: begin
            alu_input_b = (state == ST_EXEC_I) ? immediate_i : operand_b;
            if ((state == ST_EXEC_R) && (instruction[31:25] == `FUNCT7_MULDIV)) begin
                case (instruction[14:12])
                    `FUNCT3_MUL:    alu_operation = `OP_ALU_MUL;
                    `FUNCT3_MULH:   alu_operation = `OP_ALU_MULH;
                    `FUNCT3_MULHSU: alu_operation = `OP_ALU_MULHSU;
                    `FUNCT3_MULHU:  alu_operation = `OP_ALU_MULHU;
                    `FUNCT3_DIV:    alu_operation = `OP_ALU_DIV;
                    `FUNCT3_DIVU:   alu_operation = `OP_ALU_DIVU;
                    `FUNCT3_REM:    alu_operation = `OP_ALU_REM;
                    `FUNCT3_REMU:   alu_operation = `OP_ALU_REMU;
                    default:        alu_operation = `OP_ALU_NOP;
                endcase
            end else if ((state == ST_EXEC_R) &&
                         (instruction[31:25] == `FUNCT7_ZBA)) begin
                case (instruction[14:12])
                    3'b010: alu_operation = `OP_ALU_SH1ADD;
                    3'b100: alu_operation = `OP_ALU_SH2ADD;
                    3'b110: alu_operation = `OP_ALU_SH3ADD;
                    default: alu_operation = `OP_ALU_NOP;
                endcase
            end else if ((state == ST_EXEC_R) &&
                         (instruction[31:25] == `FUNCT7_ZBB_LOGICAL) &&
                         ((instruction[14:12] == 3'b100) ||
                          (instruction[14:12] == 3'b110) ||
                          (instruction[14:12] == 3'b111))) begin
                case (instruction[14:12])
                    3'b100: alu_operation = `OP_ALU_XNOR;
                    3'b110: alu_operation = `OP_ALU_ORN;
                    3'b111: alu_operation = `OP_ALU_ANDN;
                    default: alu_operation = `OP_ALU_NOP;
                endcase
            end else if ((state == ST_EXEC_R) &&
                         (instruction[31:25] == `FUNCT7_ZBB_MINMAX)) begin
                case (instruction[14:12])
                    3'b100: alu_operation = `OP_ALU_MIN;
                    3'b101: alu_operation = `OP_ALU_MINU;
                    3'b110: alu_operation = `OP_ALU_MAX;
                    3'b111: alu_operation = `OP_ALU_MAXU;
                    default: alu_operation = `OP_ALU_NOP;
                endcase
            end else if ((state == ST_EXEC_R) &&
                         (instruction[31:25] == `FUNCT7_ZBB_ROT)) begin
                alu_operation = (instruction[14:12] == 3'b001)
                                ? `OP_ALU_ROL : `OP_ALU_ROR;
            end else if ((state == ST_EXEC_R) &&
                         (instruction[31:25] == `FUNCT7_ZBS_CLEAR_EXTRACT)) begin
                alu_operation = (instruction[14:12] == 3'b001)
                                ? `OP_ALU_BCLR : `OP_ALU_BEXT;
            end else if ((state == ST_EXEC_R) &&
                         (instruction[31:25] == `FUNCT7_ZBS_INVERT)) begin
                alu_operation = `OP_ALU_BINV;
            end else if ((state == ST_EXEC_R) &&
                         (instruction[31:25] == `FUNCT7_ZBS_SET) &&
                         (instruction[14:12] == 3'b001)) begin
                alu_operation = `OP_ALU_BSET;
            end else if ((state == ST_EXEC_R) &&
                         (instruction[31:25] == `FUNCT7_ZBS_SET) &&
                         (instruction[14:12] == 3'b100)) begin
                alu_operation = `OP_ALU_ZEXTH;
            end else if ((state == ST_EXEC_I) &&
                         (instruction[31:20] == 12'h600)) begin
                alu_operation = `OP_ALU_CLZ;
            end else if ((state == ST_EXEC_I) &&
                         (instruction[31:20] == 12'h601)) begin
                alu_operation = `OP_ALU_CTZ;
            end else if ((state == ST_EXEC_I) &&
                         (instruction[31:20] == 12'h602)) begin
                alu_operation = `OP_ALU_CPOP;
            end else if ((state == ST_EXEC_I) &&
                         (instruction[31:20] == 12'h604)) begin
                alu_operation = `OP_ALU_SEXTB;
            end else if ((state == ST_EXEC_I) &&
                         (instruction[31:20] == 12'h605)) begin
                alu_operation = `OP_ALU_SEXTH;
            end else if ((state == ST_EXEC_I) &&
                         (instruction[31:25] == `FUNCT7_ZBS_SET) &&
                         (instruction[14:12] == 3'b001)) begin
                alu_operation = `OP_ALU_BSET;
            end else if ((state == ST_EXEC_I) &&
                         (instruction[31:25] == `FUNCT7_ZBS_CLEAR_EXTRACT)) begin
                alu_operation = (instruction[14:12] == 3'b001)
                                ? `OP_ALU_BCLR : `OP_ALU_BEXT;
            end else if ((state == ST_EXEC_I) &&
                         (instruction[31:25] == `FUNCT7_ZBS_INVERT) &&
                         (instruction[14:12] == 3'b001)) begin
                alu_operation = `OP_ALU_BINV;
            end else if ((state == ST_EXEC_I) &&
                         (instruction[31:25] == `FUNCT7_ZBB_ROT) &&
                         (instruction[14:12] == 3'b101)) begin
                alu_operation = `OP_ALU_ROR;
            end else if ((state == ST_EXEC_I) &&
                         (instruction[31:20] == 12'h287)) begin
                alu_operation = `OP_ALU_ORCB;
            end else if ((state == ST_EXEC_I) &&
                         (instruction[31:20] == 12'h698)) begin
                alu_operation = `OP_ALU_REV8;
            end else begin
                case (instruction[14:12])
                    `FUNCT3_ADD_SUB:
                        alu_operation = ((state == ST_EXEC_R) && instruction[30])
                                        ? `OP_ALU_SUB : `OP_ALU_ADD;
                    `FUNCT3_SLL:     alu_operation = `OP_ALU_SLL;
                    `FUNCT3_SLT:     alu_operation = `OP_ALU_SLT;
                    `FUNCT3_SLTU:    alu_operation = `OP_ALU_SLTU;
                    `FUNCT3_XOR:     alu_operation = `OP_ALU_XOR;
                    `FUNCT3_SRL_SRA:
                        alu_operation = instruction[30] ? `OP_ALU_SRA : `OP_ALU_SRL;
                    `FUNCT3_OR:      alu_operation = `OP_ALU_OR;
                    `FUNCT3_AND:     alu_operation = `OP_ALU_AND;
                    default:         alu_operation = `OP_ALU_NOP;
                endcase
            end
        end

        ST_EXEC_U: begin
            alu_input_b = immediate_u;
            if (instruction[6:0] == `OP_LUI) begin
                alu_input_a = 32'b0;
                alu_operation = `OP_ALU_PASS_B;
            end else begin
                alu_input_a = instruction_pc;
                alu_operation = `OP_ALU_ADD;
            end
        end

        ST_ADDR: begin
            alu_input_b = (instruction[6:0] == `OP_LOAD) ? immediate_i : immediate_s;
            alu_operation = `OP_ALU_ADD;
        end

        ST_BRANCH: begin
            alu_input_a = instruction_pc;
            alu_input_b = immediate_b;
            alu_operation = `OP_ALU_ADD;
        end

        ST_JUMP: begin
            if (instruction[6:0] == `OP_JAL) begin
                alu_input_a = instruction_pc;
                alu_input_b = immediate_j;
            end else begin
                alu_input_a = operand_a;
                alu_input_b = immediate_i;
            end
            alu_operation = `OP_ALU_ADD;
        end

        default: begin
            alu_operation = `OP_ALU_NOP;
        end
    endcase
end

task request_trap;
    input [31:0] cause;
    input [31:0] value;
    input [31:0] exception_pc;
    begin
        pending_cause <= cause;
        pending_tval <= value;
        pending_epc <= exception_pc;
        state <= ST_TRAP;
    end
endtask

task begin_writeback;
    input [4:0] destination;
    input [31:0] value;
    begin
        writeback_register <= destination;
        writeback_data <= value;
        writeback_valid <= 1'b1;
        state <= ST_WB;
    end
endtask

function csr_exists;
    input [11:0] address;
    begin
        case (address)
            CSR_MSTATUS, CSR_MISA, CSR_MIE, CSR_MTVEC,
            CSR_MSCRATCH, CSR_MEPC, CSR_MCAUSE, CSR_MTVAL, CSR_MIP,
            CSR_MCYCLE, CSR_MINSTRET, CSR_MCYCLEH, CSR_MINSTRETH,
            CSR_CYCLE, CSR_TIME, CSR_INSTRET, CSR_CYCLEH, CSR_TIMEH, CSR_INSTRETH,
            CSR_MVENDORID, CSR_MARCHID, CSR_MIMPID, CSR_MHARTID:
                csr_exists = 1'b1;
            default:
                csr_exists = 1'b0;
        endcase
    end
endfunction

function csr_is_writable;
    input [11:0] address;
    begin
        case (address)
            CSR_MSTATUS, CSR_MIE, CSR_MTVEC, CSR_MSCRATCH,
            CSR_MEPC, CSR_MCAUSE, CSR_MTVAL, CSR_MCYCLE, CSR_MINSTRET,
            CSR_MCYCLEH, CSR_MINSTRETH:
                csr_is_writable = 1'b1;
            default:
                csr_is_writable = 1'b0;
        endcase
    end
endfunction

function [31:0] read_csr;
    input [11:0] address;
    begin
        case (address)
            CSR_MSTATUS:  read_csr = csr_mstatus;
            CSR_MISA:     read_csr = 32'h40001102;
            CSR_MIE:      read_csr = csr_mie;
            CSR_MTVEC:    read_csr = csr_mtvec;
            CSR_MSCRATCH: read_csr = csr_mscratch;
            CSR_MEPC:     read_csr = csr_mepc;
            CSR_MCAUSE:   read_csr = csr_mcause;
            CSR_MTVAL:    read_csr = csr_mtval;
            CSR_MIP:      read_csr = interrupt_pending;
            CSR_MCYCLE, CSR_CYCLE:
                read_csr = csr_mcycle[31:0];
            CSR_MCYCLEH, CSR_CYCLEH:
                read_csr = csr_mcycle[63:32];
            CSR_MINSTRET, CSR_INSTRET:
                read_csr = csr_minstret[31:0];
            CSR_MINSTRETH, CSR_INSTRETH:
                read_csr = csr_minstret[63:32];
            CSR_TIME, CSR_TIMEH, CSR_MVENDORID, CSR_MARCHID, CSR_MIMPID, CSR_MHARTID:
                read_csr = 32'b0;
            default:
                read_csr = 32'b0;
        endcase
    end
endfunction

always @(posedge clk) begin
    if (reset) begin
        state <= ST_FETCH;
        pc <= RESET_PC;
        instruction <= 32'b0;
        instruction_pc <= RESET_PC;
        operand_a <= 32'b0;
        operand_b <= 32'b0;
        address_register <= 32'b0;
        writeback_data <= 32'b0;
        writeback_register <= 5'b0;
        writeback_valid <= 1'b0;
        pending_cause <= 32'b0;
        pending_tval <= 32'b0;
        pending_epc <= 32'b0;
        csr_mstatus <= 32'h00001800;
        csr_mie <= 32'b0;
        csr_mtvec <= 32'b0;
        csr_mscratch <= 32'b0;
        csr_mepc <= 32'b0;
        csr_mcause <= 32'b0;
        csr_mtval <= 32'b0;
        csr_mcycle <= 64'b0;
        csr_minstret <= 64'b0;
        trap_taken <= 1'b0;
        last_trap_cause <= 32'b0;
    end else begin
        csr_mcycle <= csr_mcycle + 64'd1;
        trap_taken <= 1'b0;

        case (state)
            ST_FETCH: begin
                if (csr_mstatus[3] && (csr_mie & interrupt_pending) != 0) begin
                    if ((csr_mie & interrupt_pending & 32'h00000800) != 0)
                        request_trap(CAUSE_MACHINE_EXTERNAL_IRQ, 32'b0, pc);
                    else if ((csr_mie & interrupt_pending & 32'h00000080) != 0)
                        request_trap(CAUSE_MACHINE_TIMER_IRQ, 32'b0, pc);
                    else
                        request_trap(CAUSE_MACHINE_SOFTWARE_IRQ, 32'b0, pc);
                end else if (pc[1:0] != 2'b00) begin
                    request_trap(CAUSE_INSTRUCTION_MISALIGNED, pc, pc);
                end else if (pc[31:2] >= IMEM_WORDS) begin
                    request_trap(CAUSE_INSTRUCTION_ACCESS, pc, pc);
                end else begin
                    instruction <= instruction_word;
                    instruction_pc <= pc;
                    pc <= pc + 32'd4;
                    state <= ST_DECODE;
                end
            end

            ST_DECODE: begin
                operand_a <= register_read_data1;
                operand_b <= register_read_data2;
                if (decode_illegal)
                    request_trap(CAUSE_ILLEGAL_INSTRUCTION, instruction, instruction_pc);
                else if (decode_r_type)
                    state <= ST_EXEC_R;
                else if (decode_i_type)
                    state <= ST_EXEC_I;
                else if (decode_u_type)
                    state <= ST_EXEC_U;
                else if (decode_load || decode_store)
                    state <= ST_ADDR;
                else if (decode_branch)
                    state <= ST_BRANCH;
                else if (decode_jal || decode_jalr)
                    state <= ST_JUMP;
                else if (decode_fence) begin
                    csr_minstret <= csr_minstret + 64'd1;
                    state <= ST_FETCH;
                end else if (decode_ecall) begin
                    request_trap(CAUSE_MACHINE_ECALL, 32'b0, instruction_pc);
                end else if (decode_ebreak) begin
                    request_trap(CAUSE_BREAKPOINT, 32'b0, instruction_pc);
                end else if (decode_mret) begin
                    state <= ST_MRET;
                end else if (decode_csr) begin
                    state <= ST_CSR;
                end else begin
                    request_trap(CAUSE_ILLEGAL_INSTRUCTION, instruction, instruction_pc);
                end
            end

            ST_EXEC_R: begin
                begin_writeback(instruction[11:7], alu_result);
            end

            ST_EXEC_I: begin
                begin_writeback(instruction[11:7], alu_result);
            end

            ST_EXEC_U: begin
                begin_writeback(instruction[11:7], alu_result);
            end

            ST_ADDR: begin
                address_register <= alu_result;
                if (decode_load)
                    state <= ST_LOAD;
                else
                    state <= ST_STORE;
            end

            ST_LOAD: begin
                case (instruction[14:12])
                    `LOAD_LB, `LOAD_LBU: begin
                        if (address_register >= DMEM_BYTES) begin
                            request_trap(CAUSE_LOAD_ACCESS, address_register, instruction_pc);
                        end else begin
                            memory_value = data_read_word >> {address_register[1:0], 3'b000};
                            if (instruction[14:12] == `LOAD_LB)
                                memory_value = {{24{memory_value[7]}}, memory_value[7:0]};
                            else
                                memory_value = {24'b0, memory_value[7:0]};
                            begin_writeback(instruction[11:7], memory_value);
                        end
                    end

                    `LOAD_LH, `LOAD_LHU: begin
                        if (address_register[0] != 1'b0) begin
                            request_trap(CAUSE_LOAD_MISALIGNED, address_register, instruction_pc);
                        end else if ((address_register >= DMEM_BYTES) ||
                                     ((DMEM_BYTES - address_register) < 2)) begin
                            request_trap(CAUSE_LOAD_ACCESS, address_register, instruction_pc);
                        end else begin
                            memory_value = data_read_word >> {address_register[1], 4'b0000};
                            if (instruction[14:12] == `LOAD_LH)
                                memory_value = {{16{memory_value[15]}}, memory_value[15:0]};
                            else
                                memory_value = {16'b0, memory_value[15:0]};
                            begin_writeback(instruction[11:7], memory_value);
                        end
                    end

                    `LOAD_LW: begin
                        if (address_register[1:0] != 2'b00) begin
                            request_trap(CAUSE_LOAD_MISALIGNED, address_register, instruction_pc);
                        end else if ((address_register >= DMEM_BYTES) ||
                                     ((DMEM_BYTES - address_register) < 4)) begin
                            request_trap(CAUSE_LOAD_ACCESS, address_register, instruction_pc);
                        end else begin
                            begin_writeback(instruction[11:7], data_read_word);
                        end
                    end

                    default:
                        request_trap(CAUSE_ILLEGAL_INSTRUCTION, instruction, instruction_pc);
                endcase
            end

            ST_STORE: begin
                case (instruction[14:12])
                    `STORE_SB: begin
                        if (address_register >= DMEM_BYTES) begin
                            request_trap(CAUSE_STORE_ACCESS, address_register, instruction_pc);
                        end else begin
                            csr_minstret <= csr_minstret + 64'd1;
                            state <= ST_FETCH;
                        end
                    end

                    `STORE_SH: begin
                        if (address_register[0] != 1'b0) begin
                            request_trap(CAUSE_STORE_MISALIGNED, address_register, instruction_pc);
                        end else if ((address_register >= DMEM_BYTES) ||
                                     ((DMEM_BYTES - address_register) < 2)) begin
                            request_trap(CAUSE_STORE_ACCESS, address_register, instruction_pc);
                        end else begin
                            csr_minstret <= csr_minstret + 64'd1;
                            state <= ST_FETCH;
                        end
                    end

                    `STORE_SW: begin
                        if (address_register[1:0] != 2'b00) begin
                            request_trap(CAUSE_STORE_MISALIGNED, address_register, instruction_pc);
                        end else if ((address_register >= DMEM_BYTES) ||
                                     ((DMEM_BYTES - address_register) < 4)) begin
                            request_trap(CAUSE_STORE_ACCESS, address_register, instruction_pc);
                        end else begin
                            csr_minstret <= csr_minstret + 64'd1;
                            state <= ST_FETCH;
                        end
                    end

                    default:
                        request_trap(CAUSE_ILLEGAL_INSTRUCTION, instruction, instruction_pc);
                endcase
            end

            ST_BRANCH: begin
                if (branch_condition) begin
                    computed_value = alu_result;
                    if (computed_value[1:0] != 2'b00) begin
                        request_trap(CAUSE_INSTRUCTION_MISALIGNED, computed_value, instruction_pc);
                    end else begin
                        pc <= computed_value;
                        csr_minstret <= csr_minstret + 64'd1;
                        state <= ST_FETCH;
                    end
                end else begin
                    csr_minstret <= csr_minstret + 64'd1;
                    state <= ST_FETCH;
                end
            end

            ST_JUMP: begin
                if (instruction[6:0] == `OP_JAL)
                    computed_value = alu_result;
                else
                    computed_value = alu_result & 32'hfffffffe;

                if (computed_value[1:0] != 2'b00) begin
                    request_trap(CAUSE_INSTRUCTION_MISALIGNED, computed_value, instruction_pc);
                end else begin
                    pc <= computed_value;
                    begin_writeback(instruction[11:7], instruction_pc + 32'd4);
                end
            end

            ST_CSR: begin
                if (!csr_exists(instruction[31:20])) begin
                    request_trap(CAUSE_ILLEGAL_INSTRUCTION, instruction, instruction_pc);
                end else begin
                    csr_old_value = read_csr(instruction[31:20]);
                    if ((instruction[14:12] == 3'b101) ||
                        (instruction[14:12] == 3'b110) ||
                        (instruction[14:12] == 3'b111))
                        csr_source_value = {27'b0, instruction[19:15]};
                    else
                        csr_source_value = register_read_data1;

                    case (instruction[14:12])
                        3'b001, 3'b101: begin
                            csr_new_value = csr_source_value;
                            csr_write_requested = 1'b1;
                        end
                        3'b010, 3'b110: begin
                            csr_new_value = csr_old_value | csr_source_value;
                            csr_write_requested = (instruction[19:15] != 5'b0);
                        end
                        3'b011, 3'b111: begin
                            csr_new_value = csr_old_value & ~csr_source_value;
                            csr_write_requested = (instruction[19:15] != 5'b0);
                        end
                        default: begin
                            csr_new_value = csr_old_value;
                            csr_write_requested = 1'b0;
                        end
                    endcase

                    if (csr_write_requested && !csr_is_writable(instruction[31:20])) begin
                        request_trap(CAUSE_ILLEGAL_INSTRUCTION, instruction, instruction_pc);
                    end else begin
                        if (csr_write_requested) begin
                            case (instruction[31:20])
                                CSR_MSTATUS:
                                    csr_mstatus <= (csr_new_value & 32'h00000088) | 32'h00001800;
                                CSR_MIE:
                                    csr_mie <= csr_new_value & 32'h00000888;
                                CSR_MTVEC:
                                    csr_mtvec <= {csr_new_value[31:2],
                                                  (csr_new_value[1:0] == 2'b01) ? 2'b01 : 2'b00};
                                CSR_MSCRATCH:
                                    csr_mscratch <= csr_new_value;
                                CSR_MEPC:
                                    csr_mepc <= {csr_new_value[31:2], 2'b00};
                                CSR_MCAUSE:
                                    csr_mcause <= csr_new_value;
                                CSR_MTVAL:
                                    csr_mtval <= csr_new_value;
                                CSR_MCYCLE:
                                    csr_mcycle[31:0] <= csr_new_value;
                                CSR_MCYCLEH:
                                    csr_mcycle[63:32] <= csr_new_value;
                                CSR_MINSTRET:
                                    csr_minstret[31:0] <= csr_new_value;
                                CSR_MINSTRETH:
                                    csr_minstret[63:32] <= csr_new_value;
                                default: begin
                                end
                            endcase
                        end
                        begin_writeback(instruction[11:7], csr_old_value);
                    end
                end
            end

            ST_WB: begin
                writeback_valid <= 1'b0;
                csr_minstret <= csr_minstret + 64'd1;
                state <= ST_FETCH;
            end

            ST_TRAP: begin
                csr_mepc <= {pending_epc[31:2], 2'b00};
                csr_mcause <= pending_cause;
                csr_mtval <= pending_tval;
                csr_mstatus <= (csr_mstatus & ~32'h00001888) | 32'h00001880;
                if (pending_cause[31] && (csr_mtvec[1:0] == 2'b01))
                    pc <= {csr_mtvec[31:2], 2'b00} +
                          ({1'b0, pending_cause[30:0]} << 2);
                else
                    pc <= {csr_mtvec[31:2], 2'b00};
                last_trap_cause <= pending_cause;
                trap_taken <= 1'b1;
                state <= ST_FETCH;
            end

            ST_MRET: begin
                pc <= csr_mepc;
                csr_mstatus <= (csr_mstatus & ~32'h00001888) |
                               ((csr_mstatus[7]) ? 32'h00000008 : 32'b0) |
                               32'h00001880;
                csr_minstret <= csr_minstret + 64'd1;
                state <= ST_FETCH;
            end

            default: begin
                request_trap(CAUSE_ILLEGAL_INSTRUCTION, instruction, instruction_pc);
            end
        endcase
    end
end

endmodule
