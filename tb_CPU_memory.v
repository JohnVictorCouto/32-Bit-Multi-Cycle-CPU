`timescale 1ns/1ps

module tb_CPU_memory;

reg clk;
reg reset;
wire [31:0] pc;
wire trap_taken;
wire [31:0] last_trap_cause;
integer i;

CPU #(
    .IMEM_WORDS(64),
    .DMEM_BYTES(63)
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

function [31:0] encode_s;
    input [11:0] immediate;
    input [4:0] rs2;
    input [4:0] rs1;
    input [2:0] funct3;
    begin
        encode_s = {immediate[11:5], rs2, rs1, funct3, immediate[4:0], 7'h23};
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

task prepare_exception_case;
    input [31:0] faulting_instruction;
    input [31:0] expected_cause;
    input [31:0] expected_tval;
    begin
        reset = 1'b1;
        for (i = 0; i < 63; i = i + 1)
            dut.dmem.memory[i] = 8'b0;

        dut.imem.memory[0] = 32'h04000093;
        dut.imem.memory[1] = encode_csr(12'h305, 5'd1, 3'b001, 5'd0);
        dut.imem.memory[2] = faulting_instruction;
        dut.imem.memory[3] = 32'h0000006f;
        dut.imem.memory[16] = encode_csr(12'h342, 5'd0, 3'b010, 5'd10);
        dut.imem.memory[17] = encode_csr(12'h343, 5'd0, 3'b010, 5'd11);
        dut.imem.memory[18] = 32'h0000006f;

        repeat (2) @(negedge clk);
        reset = 1'b0;
        repeat (120) @(posedge clk);
        #1;

        if (last_trap_cause !== expected_cause)
            $fatal(1, "Expected trap cause %0d, got %0d", expected_cause, last_trap_cause);
        if (dut.csr_mepc !== 32'd8)
            $fatal(1, "Unexpected mepc for memory trap: %h", dut.csr_mepc);
        if (dut.csr_mtval !== expected_tval)
            $fatal(1, "Expected mtval %h, got %h", expected_tval, dut.csr_mtval);
        if (dut.rf.registers[10] !== expected_cause ||
            dut.rf.registers[11] !== expected_tval)
            $fatal(1, "Trap handler did not read mcause/mtval");
        if (dut.dmem.memory[0] !== 8'b0 ||
            dut.dmem.memory[1] !== 8'b0 ||
            dut.dmem.memory[2] !== 8'b0 ||
            dut.dmem.memory[3] !== 8'b0)
            $fatal(1, "Faulting store modified data memory");
    end
endtask

initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
end

initial begin
    reset = 1'b1;
    #1;
    dut.imem.memory[0] = 32'h08000093;
    dut.imem.memory[1] = encode_s(12'd0, 5'd1, 5'd0, 3'b000);
    dut.imem.memory[2] = encode_i(12'd0, 5'd0, 3'b000, 5'd2, 7'h03);
    dut.imem.memory[3] = encode_i(12'd0, 5'd0, 3'b100, 5'd3, 7'h03);
    dut.imem.memory[4] = 32'h12300213;
    dut.imem.memory[5] = encode_s(12'd2, 5'd4, 5'd0, 3'b001);
    dut.imem.memory[6] = encode_i(12'd2, 5'd0, 3'b001, 5'd5, 7'h03);
    dut.imem.memory[7] = encode_i(12'd2, 5'd0, 3'b101, 5'd6, 7'h03);
    dut.imem.memory[8] = encode_s(12'd4, 5'd4, 5'd0, 3'b010);
    dut.imem.memory[9] = encode_i(12'd4, 5'd0, 3'b010, 5'd7, 7'h03);
    dut.imem.memory[10] = 32'h0000006f;

    repeat (2) @(negedge clk);
    reset = 1'b0;
    repeat (160) @(posedge clk);
    #1;

    if (dut.rf.registers[2] !== 32'hffffff80 ||
        dut.rf.registers[3] !== 32'h00000080)
        $fatal(1, "LB/LBU sign extension failed");
    if (dut.rf.registers[5] !== 32'h00000123 ||
        dut.rf.registers[6] !== 32'h00000123 ||
        dut.rf.registers[7] !== 32'h00000123)
        $fatal(1, "LH/LHU/LW result incorrect");
    if (dut.dmem.memory[0] !== 8'h80 ||
        dut.dmem.memory[2] !== 8'h23 ||
        dut.dmem.memory[3] !== 8'h01 ||
        dut.dmem.memory[4] !== 8'h23 ||
        dut.dmem.memory[5] !== 8'h01)
        $fatal(1, "Store byte order or write width incorrect");

    prepare_exception_case(encode_i(12'd1, 5'd0, 3'b010, 5'd2, 7'h03), 32'd4, 32'd1);
    prepare_exception_case(encode_s(12'd2, 5'd1, 5'd0, 3'b010), 32'd6, 32'd2);
    prepare_exception_case(encode_i(12'd0, 5'd1, 3'b010, 5'd2, 7'h03), 32'd5, 32'd64);
    prepare_exception_case(encode_s(12'd0, 5'd1, 5'd1, 3'b010), 32'd7, 32'd64);
    prepare_exception_case(encode_i(12'hffe, 5'd1, 3'b001, 5'd2, 7'h03), 32'd5, 32'd62);
    prepare_exception_case(encode_s(12'hffe, 5'd1, 5'd1, 3'b001), 32'd7, 32'd62);
    prepare_exception_case(encode_i(12'hffc, 5'd1, 3'b010, 5'd2, 7'h03), 32'd5, 32'd60);
    prepare_exception_case(encode_s(12'hffc, 5'd1, 5'd1, 3'b010), 32'd7, 32'd60);
    prepare_exception_case(encode_i(12'hfff, 5'd1, 3'b001, 5'd2, 7'h03), 32'd4, 32'd63);
    prepare_exception_case(encode_s(12'hfff, 5'd1, 5'd1, 3'b001), 32'd6, 32'd63);

    $display("PASS: byte/halfword/word memory operations and fault traps");
    $finish;
end

initial begin
    #100000;
    $fatal(1, "Memory testbench timed out");
end

endmodule
