`timescale 1ns/1ps

`include "Definitions.vh"

module BranchUnit (
    input wire [2:0] funct3,
    input wire [31:0] operand_a,
    input wire [31:0] operand_b,
    output reg branch_taken
);

always @* begin
    case (funct3)
        `BRANCH_BEQ:  branch_taken = (operand_a == operand_b);
        `BRANCH_BNE:  branch_taken = (operand_a != operand_b);
        `BRANCH_BLT:  branch_taken = ($signed(operand_a) < $signed(operand_b));
        `BRANCH_BGE:  branch_taken = ($signed(operand_a) >= $signed(operand_b));
        `BRANCH_BLTU: branch_taken = (operand_a < operand_b);
        `BRANCH_BGEU: branch_taken = (operand_a >= operand_b);
        default:      branch_taken = 1'b0;
    endcase
end

endmodule
