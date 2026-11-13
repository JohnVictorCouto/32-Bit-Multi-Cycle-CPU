`timescale 1ns/1ps

`include "Definitions.vh"

module Decoder (
    input wire [31:0] instruction,
    output reg illegal_instruction,
    output reg is_r_type,
    output reg is_i_type,
    output reg is_u_type,
    output reg is_load,
    output reg is_store,
    output reg is_branch,
    output reg is_jal,
    output reg is_jalr,
    output reg is_fence,
    output reg is_csr,
    output reg is_ecall,
    output reg is_ebreak,
    output reg is_mret
);

function valid_bitmanip_r;
    input [31:0] value;
    begin
        valid_bitmanip_r = 1'b0;
        case (value[31:25])
            `FUNCT7_ZBA:
                valid_bitmanip_r = (value[14:12] == 3'b010) ||
                                   (value[14:12] == 3'b100) ||
                                   (value[14:12] == 3'b110);
            `FUNCT7_ZBB_LOGICAL:
                valid_bitmanip_r = (value[14:12] == 3'b100) ||
                                   (value[14:12] == 3'b110) ||
                                   (value[14:12] == 3'b111);
            `FUNCT7_ZBB_MINMAX:
                valid_bitmanip_r = value[14];
            `FUNCT7_ZBB_ROT:
                valid_bitmanip_r = (value[14:12] == 3'b001) ||
                                   (value[14:12] == 3'b101);
            `FUNCT7_ZBS_CLEAR_EXTRACT:
                valid_bitmanip_r = (value[14:12] == 3'b001) ||
                                   (value[14:12] == 3'b101);
            `FUNCT7_ZBS_INVERT:
                valid_bitmanip_r = (value[14:12] == 3'b001);
            `FUNCT7_ZBS_SET:
                valid_bitmanip_r = (value[14:12] == 3'b001) ||
                                   ((value[14:12] == 3'b100) &&
                                    (value[24:20] == 5'b0));
            default:
                valid_bitmanip_r = 1'b0;
        endcase
    end
endfunction

function valid_bitmanip_i;
    input [31:0] value;
    begin
        valid_bitmanip_i = 1'b0;
        if ((value[14:12] == 3'b001) &&
            ((value[31:20] == 12'h600) ||
             (value[31:20] == 12'h601) ||
             (value[31:20] == 12'h602) ||
             (value[31:20] == 12'h604) ||
             (value[31:20] == 12'h605) ||
             (value[31:25] == `FUNCT7_ZBS_SET) ||
             (value[31:25] == `FUNCT7_ZBS_CLEAR_EXTRACT) ||
             (value[31:25] == `FUNCT7_ZBS_INVERT)))
            valid_bitmanip_i = 1'b1;
        else if ((value[14:12] == 3'b101) &&
                 ((value[31:25] == `FUNCT7_ZBB_ROT) ||
                  (value[31:25] == `FUNCT7_ZBS_CLEAR_EXTRACT) ||
                  (value[31:20] == 12'h287) ||
                  (value[31:20] == 12'h698)))
            valid_bitmanip_i = 1'b1;
    end
endfunction

always @* begin
    illegal_instruction = 1'b0;
    is_r_type = 1'b0;
    is_i_type = 1'b0;
    is_u_type = 1'b0;
    is_load = 1'b0;
    is_store = 1'b0;
    is_branch = 1'b0;
    is_jal = 1'b0;
    is_jalr = 1'b0;
    is_fence = 1'b0;
    is_csr = 1'b0;
    is_ecall = 1'b0;
    is_ebreak = 1'b0;
    is_mret = 1'b0;

    case (instruction[6:0])
        `OP_ALU: begin
            if ((instruction[31:25] == `FUNCT7_DEFAULT) ||
                ((instruction[31:25] == `FUNCT7_ALT) &&
                 ((instruction[14:12] == `FUNCT3_ADD_SUB) ||
                  (instruction[14:12] == `FUNCT3_SRL_SRA))) ||
                ((instruction[31:25] == `FUNCT7_MULDIV) &&
                 ((instruction[14:12] == `FUNCT3_MUL) ||
                  (instruction[14:12] == `FUNCT3_MULH) ||
                  (instruction[14:12] == `FUNCT3_MULHSU) ||
                  (instruction[14:12] == `FUNCT3_MULHU) ||
                  (instruction[14:12] == `FUNCT3_DIV) ||
                  (instruction[14:12] == `FUNCT3_DIVU) ||
                  (instruction[14:12] == `FUNCT3_REM) ||
                  (instruction[14:12] == `FUNCT3_REMU))) ||
                valid_bitmanip_r(instruction))
                is_r_type = 1'b1;
            else
                illegal_instruction = 1'b1;
        end

        `OP_ALUI: begin
            if (((instruction[14:12] == `FUNCT3_SLL) &&
                 (instruction[31:25] != `FUNCT7_DEFAULT) &&
                 !valid_bitmanip_i(instruction)) ||
                ((instruction[14:12] == `FUNCT3_SRL_SRA) &&
                 (instruction[31:25] != `FUNCT7_DEFAULT) &&
                 (instruction[31:25] != `FUNCT7_ALT) &&
                 !valid_bitmanip_i(instruction)))
                illegal_instruction = 1'b1;
            else
                is_i_type = 1'b1;
        end

        `OP_LUI, `OP_AUIPC:
            is_u_type = 1'b1;

        `OP_LOAD: begin
            if ((instruction[14:12] == `LOAD_LB) ||
                (instruction[14:12] == `LOAD_LH) ||
                (instruction[14:12] == `LOAD_LW) ||
                (instruction[14:12] == `LOAD_LBU) ||
                (instruction[14:12] == `LOAD_LHU))
                is_load = 1'b1;
            else
                illegal_instruction = 1'b1;
        end

        `OP_STORE: begin
            if ((instruction[14:12] == `STORE_SB) ||
                (instruction[14:12] == `STORE_SH) ||
                (instruction[14:12] == `STORE_SW))
                is_store = 1'b1;
            else
                illegal_instruction = 1'b1;
        end

        `OP_BRANCH: begin
            if ((instruction[14:12] == `BRANCH_BEQ) ||
                (instruction[14:12] == `BRANCH_BNE) ||
                (instruction[14:12] == `BRANCH_BLT) ||
                (instruction[14:12] == `BRANCH_BGE) ||
                (instruction[14:12] == `BRANCH_BLTU) ||
                (instruction[14:12] == `BRANCH_BGEU))
                is_branch = 1'b1;
            else
                illegal_instruction = 1'b1;
        end

        `OP_JAL:
            is_jal = 1'b1;

        `OP_JALR: begin
            if (instruction[14:12] == 3'b000)
                is_jalr = 1'b1;
            else
                illegal_instruction = 1'b1;
        end

        `OP_FENCE: begin
            if ((instruction[14:12] == `FUNCT3_FENCE) &&
                (instruction[19:15] == 5'b0) &&
                (instruction[11:7] == 5'b0) &&
                ((instruction[31:28] == 4'b0000) ||
                 ((instruction[31:28] == 4'b1000) &&
                  (instruction[27:20] == 8'b00110011))))
                is_fence = 1'b1;
            else if ((instruction[14:12] == `FUNCT3_FENCE_I) &&
                     (instruction[31:20] == 12'b0) &&
                     (instruction[19:15] == 5'b0) &&
                     (instruction[11:7] == 5'b0))
                is_fence = 1'b1;
            else
                illegal_instruction = 1'b1;
        end

        `OP_SYSTEM: begin
            if (instruction[14:12] == 3'b000) begin
                case (instruction)
                    32'h00000073: is_ecall = 1'b1;
                    32'h00100073: is_ebreak = 1'b1;
                    32'h30200073: is_mret = 1'b1;
                    default: illegal_instruction = 1'b1;
                endcase
            end else if ((instruction[14:12] == 3'b001) ||
                         (instruction[14:12] == 3'b010) ||
                         (instruction[14:12] == 3'b011) ||
                         (instruction[14:12] == 3'b101) ||
                         (instruction[14:12] == 3'b110) ||
                         (instruction[14:12] == 3'b111)) begin
                is_csr = 1'b1;
            end else begin
                illegal_instruction = 1'b1;
            end
        end

        default:
            illegal_instruction = 1'b1;
    endcase
end

endmodule
