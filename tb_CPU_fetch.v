`timescale 1ns/1ps

module tb_CPU_fetch;

reg clk;
reg reset;
wire [31:0] pc;
wire trap_taken;
wire [31:0] last_trap_cause;

CPU #(
    .IMEM_WORDS(4),
    .DMEM_BYTES(8),
    .RESET_PC(32'd16)
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
    dut.imem.memory[0] = encode_csr(12'h342, 5'd0, 3'b010, 5'd1);
    dut.imem.memory[1] = encode_csr(12'h343, 5'd0, 3'b010, 5'd2);
    dut.imem.memory[2] = 32'h0000006f;

    repeat (2) @(negedge clk);
    reset = 1'b0;
    repeat (50) @(posedge clk);
    #1;

    if (last_trap_cause !== 32'd1 ||
        dut.csr_mepc !== 32'd16 ||
        dut.csr_mtval !== 32'd16)
        $fatal(1, "Instruction access fault CSRs are incorrect");
    if (dut.rf.registers[1] !== 32'd1 ||
        dut.rf.registers[2] !== 32'd16)
        $fatal(1, "Instruction access fault handler did not run");

    $display("PASS: instruction memory access fault and trap CSRs");
    $finish;
end

initial begin
    #100000;
    $fatal(1, "Instruction fetch testbench timed out");
end

endmodule
