`timescale 1ns/1ps

module tb_CPU_interrupt;

reg clk;
reg reset;
reg irq_software;
reg irq_timer;
reg irq_external;
wire [31:0] pc;
wire trap_taken;
wire [31:0] last_trap_cause;

CPU #(
    .IMEM_WORDS(64),
    .DMEM_BYTES(64)
) dut (
    .clk(clk),
    .reset(reset),
    .irq_software(irq_software),
    .irq_timer(irq_timer),
    .irq_external(irq_external),
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
    irq_software = 1'b0;
    irq_timer = 1'b0;
    irq_external = 1'b0;
    #1;

    dut.imem.memory[0] = 32'h04000093; // addi x1, x0, 64
    dut.imem.memory[1] = encode_csr(12'h305, 5'd1, 3'b001, 5'd0);
    dut.imem.memory[2] = 32'h000010b7; // lui x1, 1
    dut.imem.memory[3] = 32'h88808093; // addi x1, x1, -1912
    dut.imem.memory[4] = encode_csr(12'h304, 5'd1, 3'b001, 5'd0);
    dut.imem.memory[5] = 32'h00800093; // addi x1, x0, 8
    dut.imem.memory[6] = encode_csr(12'h300, 5'd1, 3'b001, 5'd0);
    dut.imem.memory[7] = 32'h02a00113; // addi x2, x0, 42
    dut.imem.memory[8] = 32'h0000006f; // jal x0, 0
    dut.imem.memory[16] = encode_csr(12'h342, 5'd0, 3'b010, 5'd10);
    dut.imem.memory[17] = 32'h30200073; // mret

    repeat (2) @(negedge clk);
    reset = 1'b0;
    wait (dut.csr_mie[11:3] == 9'h111 && dut.csr_mstatus[3]);
    #1;
    irq_software = 1'b1;
    irq_timer = 1'b1;
    irq_external = 1'b1;

    wait (trap_taken);
    #1;
    if (last_trap_cause !== 32'h8000000b)
        $fatal(1, "External interrupt did not have priority: cause=%h", last_trap_cause);

    irq_software = 1'b0;
    irq_timer = 1'b0;
    irq_external = 1'b0;
    repeat (160) @(posedge clk);
    #1;

    if (dut.rf.registers[10] !== 32'h8000000b)
        $fatal(1, "Trap handler did not read the external interrupt cause");
    if (dut.rf.registers[2] !== 32'd42)
        $fatal(1, "MRET did not resume the interrupted instruction");
    if (dut.csr_mepc !== 32'd28)
        $fatal(1, "Interrupt mepc did not point to the resume instruction");

    reset = 1'b1;
    irq_software = 1'b0;
    irq_timer = 1'b0;
    irq_external = 1'b0;
    #1;
    dut.imem.memory[0] = 32'h04000093;
    dut.imem.memory[1] = encode_csr(12'h305, 5'd1, 3'b001, 5'd0);
    dut.imem.memory[2] = 32'h000010b7;
    dut.imem.memory[3] = 32'h88808093;
    dut.imem.memory[4] = encode_csr(12'h304, 5'd1, 3'b001, 5'd0);
    dut.imem.memory[5] = 32'h00800093;
    dut.imem.memory[6] = encode_csr(12'h300, 5'd1, 3'b001, 5'd0);
    dut.imem.memory[7] = 32'h02a00113;
    dut.imem.memory[8] = 32'h0000006f;
    dut.imem.memory[16] = encode_csr(12'h342, 5'd0, 3'b010, 5'd10);
    dut.imem.memory[17] = 32'h30200073;

    repeat (2) @(negedge clk);
    reset = 1'b0;
    wait (dut.csr_mie[11:3] == 9'h111 && dut.csr_mstatus[3]);
    #1;
    irq_software = 1'b1;
    irq_timer = 1'b1;
    wait (trap_taken);
    #1;
    if (last_trap_cause !== 32'h80000007)
        $fatal(1, "Timer interrupt did not take priority over software");

    irq_software = 1'b0;
    irq_timer = 1'b0;
    repeat (160) @(posedge clk);
    #1;
    if (dut.rf.registers[10] !== 32'h80000007 ||
        dut.rf.registers[2] !== 32'd42)
        $fatal(1, "Timer interrupt handler or MRET resume failed");

    reset = 1'b1;
    irq_software = 1'b0;
    irq_timer = 1'b0;
    #1;
    dut.imem.memory[0] = 32'h04000093;
    dut.imem.memory[1] = encode_csr(12'h305, 5'd1, 3'b001, 5'd0);
    dut.imem.memory[2] = 32'h000010b7;
    dut.imem.memory[3] = 32'h88808093;
    dut.imem.memory[4] = encode_csr(12'h304, 5'd1, 3'b001, 5'd0);
    dut.imem.memory[5] = 32'h00800093;
    dut.imem.memory[6] = encode_csr(12'h300, 5'd1, 3'b001, 5'd0);
    dut.imem.memory[7] = 32'h02a00113;
    dut.imem.memory[8] = 32'h0000006f;
    dut.imem.memory[16] = encode_csr(12'h342, 5'd0, 3'b010, 5'd10);
    dut.imem.memory[17] = 32'h30200073;

    repeat (2) @(negedge clk);
    reset = 1'b0;
    wait (dut.csr_mie[11:3] == 9'h111 && dut.csr_mstatus[3]);
    #1;
    irq_software = 1'b1;
    wait (trap_taken);
    #1;
    if (last_trap_cause !== 32'h80000003)
        $fatal(1, "Software interrupt cause incorrect");
    irq_software = 1'b0;

    $display("PASS: external/timer/software priority, trap handler, and MRET resume");
    $finish;
end

initial begin
    #100000;
    $fatal(1, "Interrupt testbench timed out");
end

endmodule
