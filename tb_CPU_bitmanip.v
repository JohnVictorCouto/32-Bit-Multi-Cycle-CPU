`timescale 1ns/1ps

module tb_CPU_bitmanip;

reg clk;
reg reset;
wire [31:0] pc;
wire trap_taken;
wire [31:0] last_trap_cause;

function [31:0] encode_r;
    input [6:0] funct7;
    input [4:0] rs2;
    input [4:0] rs1;
    input [2:0] funct3;
    input [4:0] rd;
    begin
        encode_r = {funct7, rs2, rs1, funct3, rd, 7'h33};
    end
endfunction

function [31:0] encode_i;
    input [11:0] immediate;
    input [4:0] rs1;
    input [2:0] funct3;
    input [4:0] rd;
    begin
        encode_i = {immediate, rs1, funct3, rd, 7'h13};
    end
endfunction

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

initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
end

initial begin
    reset = 1'b1;
    #1;

    dut.imem.memory[0]  = encode_r(7'b0010000, 5'd2, 5'd1, 3'b010, 5'd4); // sh1add
    dut.imem.memory[1]  = encode_r(7'b0010000, 5'd2, 5'd1, 3'b100, 5'd5); // sh2add
    dut.imem.memory[2]  = encode_r(7'b0010000, 5'd2, 5'd1, 3'b110, 5'd6); // sh3add
    dut.imem.memory[3]  = encode_r(7'b0100000, 5'd2, 5'd1, 3'b111, 5'd7); // andn
    dut.imem.memory[4]  = encode_r(7'b0100000, 5'd2, 5'd1, 3'b110, 5'd8); // orn
    dut.imem.memory[5]  = encode_r(7'b0100000, 5'd2, 5'd1, 3'b100, 5'd9); // xnor
    dut.imem.memory[6]  = encode_i(12'h600, 5'd1, 3'b001, 5'd10); // clz
    dut.imem.memory[7]  = encode_i(12'h601, 5'd0, 3'b001, 5'd11); // ctz
    dut.imem.memory[8]  = encode_i(12'h602, 5'd1, 3'b001, 5'd12); // cpop
    dut.imem.memory[9]  = encode_r(7'b0000101, 5'd2, 5'd1, 3'b100, 5'd13); // min
    dut.imem.memory[10] = encode_r(7'b0000101, 5'd2, 5'd1, 3'b101, 5'd14); // minu
    dut.imem.memory[11] = encode_r(7'b0000101, 5'd2, 5'd1, 3'b110, 5'd15); // max
    dut.imem.memory[12] = encode_r(7'b0000101, 5'd2, 5'd1, 3'b111, 5'd16); // maxu
    dut.imem.memory[13] = encode_r(7'b0110000, 5'd2, 5'd1, 3'b001, 5'd17); // rol
    dut.imem.memory[14] = encode_r(7'b0110000, 5'd2, 5'd1, 3'b101, 5'd18); // ror
    dut.imem.memory[15] = encode_i(12'h603, 5'd1, 3'b101, 5'd19); // rori
    dut.imem.memory[16] = encode_i(12'h287, 5'd1, 3'b101, 5'd20); // orc.b
    dut.imem.memory[17] = encode_i(12'h698, 5'd1, 3'b101, 5'd21); // rev8
    dut.imem.memory[18] = encode_i(12'h604, 5'd1, 3'b001, 5'd22); // sext.b
    dut.imem.memory[19] = encode_i(12'h605, 5'd1, 3'b001, 5'd23); // sext.h
    dut.imem.memory[20] = encode_r(7'b0000100, 5'd0, 5'd1, 3'b100, 5'd24); // zext.h
    dut.imem.memory[21] = encode_r(7'b0100100, 5'd3, 5'd1, 3'b001, 5'd25); // bclr
    dut.imem.memory[22] = encode_r(7'b0100100, 5'd3, 5'd1, 3'b101, 5'd26); // bext
    dut.imem.memory[23] = encode_r(7'b0110100, 5'd3, 5'd1, 3'b001, 5'd27); // binv
    dut.imem.memory[24] = encode_r(7'b0000100, 5'd3, 5'd1, 3'b001, 5'd28); // bset
    dut.imem.memory[25] = encode_i(12'h487, 5'd1, 3'b001, 5'd29); // bclri
    dut.imem.memory[26] = encode_i(12'h48f, 5'd1, 3'b101, 5'd30); // bexti
    dut.imem.memory[27] = encode_i(12'h688, 5'd1, 3'b001, 5'd31); // binvi
    dut.imem.memory[28] = encode_i(12'h084, 5'd1, 3'b001, 5'd1); // bseti
    dut.imem.memory[29] = 32'h0000006f; // jal x0, 0

    repeat (2) @(posedge clk);
    @(negedge clk);
    dut.rf.registers[1] = 32'h80008081;
    dut.rf.registers[2] = 32'd3;
    dut.rf.registers[3] = 32'd31;
    reset = 1'b0;
    repeat (240) @(posedge clk);
    #1;

    if (dut.rf.registers[4] !== 32'h00000105 ||
        dut.rf.registers[5] !== 32'h00000207 ||
        dut.rf.registers[6] !== 32'h0000040b)
        $fatal(1, "Zba shifted-add results incorrect");
    if (dut.rf.registers[7] !== 32'h80008080 ||
        dut.rf.registers[8] !== 32'hfffffffd ||
        dut.rf.registers[9] !== 32'h7fff7f7d)
        $fatal(1, "Zbb logical results incorrect");
    if (dut.rf.registers[10] !== 32'd0 ||
        dut.rf.registers[11] !== 32'd32 ||
        dut.rf.registers[12] !== 32'd4)
        $fatal(1, "Zbb bit-count results incorrect");
    if (dut.rf.registers[13] !== 32'h80008081 ||
        dut.rf.registers[14] !== 32'd3 ||
        dut.rf.registers[15] !== 32'd3 ||
        dut.rf.registers[16] !== 32'h80008081)
        $fatal(1, "Zbb min/max results incorrect");
    if (dut.rf.registers[17] !== 32'h0004040c ||
        dut.rf.registers[18] !== 32'h30001010 ||
        dut.rf.registers[19] !== 32'h30001010)
        $fatal(1, "Zbb rotate results incorrect");
    if (dut.rf.registers[20] !== 32'hff00ffff ||
        dut.rf.registers[21] !== 32'h81800080 ||
        dut.rf.registers[22] !== 32'hffffff81 ||
        dut.rf.registers[23] !== 32'hffff8081 ||
        dut.rf.registers[24] !== 32'h00008081)
        $fatal(1, "Zbb byte-operation results incorrect");
    if (dut.rf.registers[25] !== 32'h00008081 ||
        dut.rf.registers[26] !== 32'd1 ||
        dut.rf.registers[27] !== 32'h00008081 ||
        dut.rf.registers[28] !== 32'h80008081 ||
        dut.rf.registers[29] !== 32'h80008001 ||
        dut.rf.registers[30] !== 32'd1 ||
        dut.rf.registers[31] !== 32'h80008181 ||
        dut.rf.registers[1] !== 32'h80008091)
        $fatal(1, "Zbs single-bit results incorrect");
    if (last_trap_cause !== 32'b0)
        $fatal(1, "Bit-manipulation instruction trapped: mcause=%h", last_trap_cause);

    $display("PASS: RV32 Zba/Zbb/Zbs instructions");
    $finish;
end

initial begin
    #100000;
    $fatal(1, "Bit-manipulation testbench timed out");
end

endmodule
