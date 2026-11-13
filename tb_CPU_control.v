`timescale 1ns/1ps

module tb_CPU_control;

reg clk;
reg reset;
wire [31:0] pc;
wire trap_taken;
wire [31:0] last_trap_cause;

CPU #(
    .IMEM_WORDS(64),
    .DMEM_BYTES(64)
) dut (
    .clk(clk),
    .reset(reset),
    .irq_software(1'b0),
    .irq_timer(1'b0),
    .irq_external(1'b0),
    .pc(pc),
    .trap_taken(trap_taken),
    .last_trap_cause(last_trap_cause)
);

function [31:0] encode_b;
    input [12:0] immediate;
    input [4:0] rs2;
    input [4:0] rs1;
    input [2:0] funct3;
    begin
        encode_b = {immediate[12], immediate[10:5], rs2, rs1, funct3,
                    immediate[4:1], immediate[11], 7'h63};
    end
endfunction

function [31:0] encode_i;
    input [11:0] immediate;
    input [4:0] rs1;
    input [2:0] funct3;
    input [4:0] rd;
    input [6:0] opcode;
    begin
        encode_i = {immediate, rs1, funct3, rd, opcode};
    end
endfunction

function [31:0] encode_csr;
    input [11:0] csr;
    input [4:0] rs1;
    input [2:0] funct3;
    input [4:0] rd;
    begin
        encode_csr = {csr, rs1, funct3, rd, 7'h73};
    end
endfunction

initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
end

initial begin
    reset = 1'b1;
    #1;
    dut.imem.memory[0] = 32'hfff00093; // addi x1, x0, -1
    dut.imem.memory[1] = 32'h00100113; // addi x2, x0, 1
    dut.imem.memory[2] = encode_b(13'd8, 5'd2, 5'd1, 3'b100); // blt taken
    dut.imem.memory[3] = 32'h06300193; // skipped
    dut.imem.memory[4] = encode_b(13'd8, 5'd2, 5'd1, 3'b101); // bge not taken
    dut.imem.memory[5] = 32'h00400213;
    dut.imem.memory[6] = encode_b(13'd8, 5'd2, 5'd1, 3'b110); // bltu not taken
    dut.imem.memory[7] = 32'h00500293;
    dut.imem.memory[8] = encode_b(13'd8, 5'd2, 5'd1, 3'b111); // bgeu taken
    dut.imem.memory[9] = 32'h06300313; // skipped
    dut.imem.memory[10] = encode_b(13'd8, 5'd1, 5'd1, 3'b000); // beq taken
    dut.imem.memory[11] = 32'h06300393; // skipped
    dut.imem.memory[12] = encode_b(13'd8, 5'd2, 5'd1, 3'b001); // bne taken
    dut.imem.memory[13] = 32'h06300413; // skipped
    dut.imem.memory[14] = 32'h04800493; // addi x9, x0, 72
    dut.imem.memory[15] = encode_i(12'd0, 5'd9, 3'b000, 5'd10, 7'h67); // jalr x10, 0(x9)
    dut.imem.memory[16] = 32'h06300593; // skipped
    dut.imem.memory[17] = 32'h06300613; // skipped
    dut.imem.memory[18] = 32'h00d00693;
    dut.imem.memory[19] = 32'h0000006f; // jal x0, 0

    repeat (2) @(negedge clk);
    reset = 1'b0;
    repeat (200) @(posedge clk);
    #1;

    if (dut.rf.registers[3] !== 32'b0 ||
        dut.rf.registers[6] !== 32'b0 ||
        dut.rf.registers[7] !== 32'b0 ||
        dut.rf.registers[8] !== 32'b0)
        $fatal(1, "A taken conditional branch executed its skipped instruction");
    if (dut.rf.registers[4] !== 32'd4 ||
        dut.rf.registers[5] !== 32'd5)
        $fatal(1, "A not-taken signed or unsigned branch skipped its next instruction");
    if (dut.rf.registers[10] !== 32'd64 ||
        dut.rf.registers[13] !== 32'd13)
        $fatal(1, "JALR target or link address incorrect");

    reset = 1'b1;
    #1;
    dut.imem.memory[0] = 32'h00500093; // addi x1, x0, 5
    dut.imem.memory[1] = encode_csr(12'h340, 5'd1, 3'b001, 5'd2); // csrrw
    dut.imem.memory[2] = encode_csr(12'h340, 5'd1, 3'b010, 5'd3); // csrrs
    dut.imem.memory[3] = encode_csr(12'h340, 5'd1, 3'b011, 5'd4); // csrrc
    dut.imem.memory[4] = encode_csr(12'h340, 5'd7, 3'b101, 5'd5); // csrrwi
    dut.imem.memory[5] = encode_csr(12'h340, 5'd2, 3'b110, 5'd6); // csrrsi
    dut.imem.memory[6] = encode_csr(12'h340, 5'd1, 3'b111, 5'd7); // csrrci
    dut.imem.memory[7] = 32'h0000006f;

    repeat (2) @(negedge clk);
    reset = 1'b0;
    repeat (100) @(posedge clk);
    #1;

    if (dut.rf.registers[2] !== 32'd0 ||
        dut.rf.registers[3] !== 32'd5 ||
        dut.rf.registers[4] !== 32'd5 ||
        dut.rf.registers[5] !== 32'd0 ||
        dut.rf.registers[6] !== 32'd7 ||
        dut.rf.registers[7] !== 32'd7 ||
        dut.csr_mscratch !== 32'd6)
        $fatal(1, "CSR register/immediate read, write, set, or clear failed");

    reset = 1'b1;
    #1;
    dut.imem.memory[0] = encode_csr(12'h301, 5'd1, 3'b001, 5'd0);
    dut.imem.memory[1] = 32'h0000006f;
    repeat (2) @(negedge clk);
    reset = 1'b0;
    repeat (30) @(posedge clk);
    #1;
    if (last_trap_cause !== 32'd2)
        $fatal(1, "Write to read-only misa did not cause an illegal instruction trap");

    reset = 1'b1;
    #1;
    dut.imem.memory[0] = encode_csr(12'h777, 5'd0, 3'b010, 5'd1);
    repeat (2) @(negedge clk);
    reset = 1'b0;
    repeat (30) @(posedge clk);
    #1;
    if (last_trap_cause !== 32'd2)
        $fatal(1, "Access to unimplemented CSR did not cause an illegal instruction trap");

    $display("PASS: branch conditions, JALR, CSR operations, and CSR traps");
    $finish;
end

initial begin
    #100000;
    $fatal(1, "Control and CSR testbench timed out");
end

endmodule
