`timescale 1ns/1ps

`include "Definitions.vh"

module ALU (
    input wire [31:0] operand_a,
    input wire [31:0] operand_b,
    input wire [7:0] operation,
    output reg [31:0] result
);

reg signed [63:0] product_ss;
reg signed [63:0] product_su;
reg [63:0] product_uu;
reg [31:0] bit_mask;
reg found;
integer bit_index;
integer bit_count;

always @* begin
    product_ss = $signed({{32{operand_a[31]}}, operand_a}) *
                 $signed({{32{operand_b[31]}}, operand_b});
    product_su = $signed({{32{operand_a[31]}}, operand_a}) *
                 $signed({32'b0, operand_b});
    product_uu = {32'b0, operand_a} * {32'b0, operand_b};
    bit_mask = 32'b0;
    found = 1'b0;
    bit_index = 0;
    bit_count = 0;

    case (operation)
        `OP_ALU_ADD:    result = operand_a + operand_b;
        `OP_ALU_SUB:    result = operand_a - operand_b;
        `OP_ALU_AND:    result = operand_a & operand_b;
        `OP_ALU_OR:     result = operand_a | operand_b;
        `OP_ALU_XOR:    result = operand_a ^ operand_b;
        `OP_ALU_SLT:    result = ($signed(operand_a) < $signed(operand_b)) ? 32'd1 : 32'd0;
        `OP_ALU_SLTU:   result = (operand_a < operand_b) ? 32'd1 : 32'd0;
        `OP_ALU_SLL:    result = operand_a << operand_b[4:0];
        `OP_ALU_SRL:    result = operand_a >> operand_b[4:0];
        `OP_ALU_SRA:    result = $signed(operand_a) >>> operand_b[4:0];
        `OP_ALU_MUL:    result = product_uu[31:0];
        `OP_ALU_MULH:   result = product_ss[63:32];
        `OP_ALU_MULHSU: result = product_su[63:32];
        `OP_ALU_MULHU:  result = product_uu[63:32];
        `OP_ALU_DIV: begin
            if (operand_b == 32'b0)
                result = {32{1'b1}};
            else if ((operand_a == 32'h80000000) && (operand_b == 32'hffffffff))
                result = 32'h80000000;
            else
                result = $signed(operand_a) / $signed(operand_b);
        end
        `OP_ALU_DIVU: begin
            if (operand_b == 32'b0)
                result = {32{1'b1}};
            else
                result = operand_a / operand_b;
        end
        `OP_ALU_REM: begin
            if (operand_b == 32'b0)
                result = operand_a;
            else if ((operand_a == 32'h80000000) && (operand_b == 32'hffffffff))
                result = 32'd0;
            else
                result = $signed(operand_a) % $signed(operand_b);
        end
        `OP_ALU_REMU: begin
            if (operand_b == 32'b0)
                result = operand_a;
            else
                result = operand_a % operand_b;
        end
        `OP_ALU_PASS_B: result = operand_b;
        `OP_ALU_ANDN:   result = operand_a & ~operand_b;
        `OP_ALU_ORN:    result = operand_a | ~operand_b;
        `OP_ALU_XNOR:   result = ~(operand_a ^ operand_b);
        `OP_ALU_CLZ: begin
            result = 32'd32;
            for (bit_index = 31; bit_index >= 0; bit_index = bit_index - 1) begin
                if (!found && operand_a[bit_index]) begin
                    result = 31 - bit_index;
                    found = 1'b1;
                end
            end
        end
        `OP_ALU_CTZ: begin
            result = 32'd32;
            for (bit_index = 0; bit_index < 32; bit_index = bit_index + 1) begin
                if (!found && operand_a[bit_index]) begin
                    result = bit_index;
                    found = 1'b1;
                end
            end
        end
        `OP_ALU_CPOP: begin
            for (bit_index = 0; bit_index < 32; bit_index = bit_index + 1)
                bit_count = bit_count + operand_a[bit_index];
            result = bit_count;
        end
        `OP_ALU_MIN:
            result = ($signed(operand_a) < $signed(operand_b)) ? operand_a : operand_b;
        `OP_ALU_MINU:
            result = (operand_a < operand_b) ? operand_a : operand_b;
        `OP_ALU_MAX:
            result = ($signed(operand_a) > $signed(operand_b)) ? operand_a : operand_b;
        `OP_ALU_MAXU:
            result = (operand_a > operand_b) ? operand_a : operand_b;
        `OP_ALU_ROL: begin
            if (operand_b[4:0] == 5'b0)
                result = operand_a;
            else
                result = (operand_a << operand_b[4:0]) |
                         (operand_a >> (32 - operand_b[4:0]));
        end
        `OP_ALU_ROR: begin
            if (operand_b[4:0] == 5'b0)
                result = operand_a;
            else
                result = (operand_a >> operand_b[4:0]) |
                         (operand_a << (32 - operand_b[4:0]));
        end
        `OP_ALU_ORCB: begin
            result[7:0]   = (|operand_a[7:0])   ? 8'hff : 8'h00;
            result[15:8]  = (|operand_a[15:8])  ? 8'hff : 8'h00;
            result[23:16] = (|operand_a[23:16]) ? 8'hff : 8'h00;
            result[31:24] = (|operand_a[31:24]) ? 8'hff : 8'h00;
        end
        `OP_ALU_REV8:   result = {operand_a[7:0], operand_a[15:8],
                                  operand_a[23:16], operand_a[31:24]};
        `OP_ALU_SEXTB:  result = {{24{operand_a[7]}}, operand_a[7:0]};
        `OP_ALU_SEXTH:  result = {{16{operand_a[15]}}, operand_a[15:0]};
        `OP_ALU_ZEXTH:  result = {16'b0, operand_a[15:0]};
        `OP_ALU_BCLR: begin
            bit_mask = 32'b1 << operand_b[4:0];
            result = operand_a & ~bit_mask;
        end
        `OP_ALU_BEXT:   result = (operand_a >> operand_b[4:0]) & 32'b1;
        `OP_ALU_BINV: begin
            bit_mask = 32'b1 << operand_b[4:0];
            result = operand_a ^ bit_mask;
        end
        `OP_ALU_BSET: begin
            bit_mask = 32'b1 << operand_b[4:0];
            result = operand_a | bit_mask;
        end
        `OP_ALU_SH1ADD: result = (operand_a << 1) + operand_b;
        `OP_ALU_SH2ADD: result = (operand_a << 2) + operand_b;
        `OP_ALU_SH3ADD: result = (operand_a << 3) + operand_b;
        default:        result = 32'b0;
    endcase
end

endmodule
