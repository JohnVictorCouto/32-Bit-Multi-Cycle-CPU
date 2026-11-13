`timescale 1ns/1ps

module tb_CPU;

reg clk;
reg reset;
wire [31:0] pc;
wire trap_taken;
wire [31:0] last_trap_cause;
reg saw_trap;

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

always @(posedge clk) begin
    if (trap_taken)
        saw_trap <= 1'b1;
end

initial begin
    reset = 1'b1;
    saw_trap = 1'b0;
    #1;

    dut.imem.memory[0]  = 32'h00500093; // addi x1, x0, 5
    dut.imem.memory[1]  = 32'h00700113; // addi x2, x0, 7
    dut.imem.memory[2]  = 32'h002081b3; // add x3, x1, x2
    dut.imem.memory[3]  = 32'h00302023; // sw x3, 0(x0)
    dut.imem.memory[4]  = 32'h00000203; // lb x4, 0(x0)
    dut.imem.memory[5]  = 32'h00100293; // addi x5, x0, 1
    dut.imem.memory[6]  = 32'h00320463; // beq x4, x3, +8
    dut.imem.memory[7]  = 32'h06300313; // skipped: addi x6, x0, 99
    dut.imem.memory[8]  = 32'h00900313; // addi x6, x0, 9
    dut.imem.memory[9]  = 32'h008003ef; // jal x7, +8
    dut.imem.memory[10] = 32'h06400313; // skipped: addi x6, x0, 100
    dut.imem.memory[11] = 32'h02a00413; // addi x8, x0, 42
    dut.imem.memory[12] = 32'h04000493; // addi x9, x0, 64
    dut.imem.memory[13] = 32'h30549073; // csrrw x0, mtvec, x9
    dut.imem.memory[14] = 32'h00100073; // ebreak
    dut.imem.memory[15] = 32'h00100513; // skipped by trap
    dut.imem.memory[16] = 32'h04d00513; // trap handler: addi x10, x0, 77
    dut.imem.memory[17] = 32'h0000006f; // jal x0, 0

    repeat (2) @(posedge clk);
    reset = 1'b0;
    repeat (300) @(posedge clk);
    #1;

    if (dut.rf.registers[3] !== 32'd12)
        $fatal(1, "ADD result incorrect: x3=%0d", dut.rf.registers[3]);
    if (dut.dmem.memory[0] !== 8'd12)
        $fatal(1, "SW result incorrect: mem[0]=%0d", dut.dmem.memory[0]);
    if (dut.rf.registers[4] !== 32'd12)
        $fatal(1, "LB result incorrect: x4=%0d", dut.rf.registers[4]);
    if (dut.rf.registers[6] !== 32'd9)
        $fatal(1, "Branch/JAL control flow incorrect: x6=%0d", dut.rf.registers[6]);
    if (dut.rf.registers[7] !== 32'd40)
        $fatal(1, "JAL link address incorrect: x7=%0d", dut.rf.registers[7]);
    if (dut.rf.registers[8] !== 32'd42)
        $fatal(1, "JAL target incorrect: x8=%0d", dut.rf.registers[8]);
    if (last_trap_cause !== 32'd3)
        $fatal(1, "EBREAK cause incorrect: mcause=%h", last_trap_cause);
    if (!saw_trap)
        $fatal(1, "EBREAK trap pulse was not observed");
    if (dut.csr_mepc !== 32'd56)
        $fatal(1, "EBREAK mepc incorrect: mepc=%h", dut.csr_mepc);
    if (dut.rf.registers[10] !== 32'd77)
        $fatal(1, "Trap handler did not run: x10=%0d", dut.rf.registers[10]);

    // RV32M extension validation using the same tb_CPU testbench.
    reset = 1'b1;
    #1;
    dut.imem.memory[0] = 32'h800000b7; // lui x1, 0x80000
    dut.imem.memory[1] = 32'h00200113; // addi x2, x0, 2
    dut.imem.memory[2] = encode_r(7'b0000001, 5'd2, 5'd1, 3'b000, 5'd3);
    dut.imem.memory[3] = encode_r(7'b0000001, 5'd2, 5'd1, 3'b001, 5'd4);
    dut.imem.memory[4] = encode_r(7'b0000001, 5'd2, 5'd1, 3'b010, 5'd5);
    dut.imem.memory[5] = encode_r(7'b0000001, 5'd2, 5'd1, 3'b011, 5'd6);
    dut.imem.memory[6] = encode_r(7'b0000001, 5'd2, 5'd1, 3'b100, 5'd7);
    dut.imem.memory[7] = encode_r(7'b0000001, 5'd2, 5'd1, 3'b101, 5'd8);
    dut.imem.memory[8] = encode_r(7'b0000001, 5'd2, 5'd1, 3'b110, 5'd9);
    dut.imem.memory[9] = encode_r(7'b0000001, 5'd2, 5'd1, 3'b111, 5'd10);
    dut.imem.memory[10] = encode_r(7'b0000001, 5'd0, 5'd1, 3'b100, 5'd12);
    dut.imem.memory[11] = encode_r(7'b0000001, 5'd0, 5'd1, 3'b101, 5'd13);
    dut.imem.memory[12] = encode_r(7'b0000001, 5'd0, 5'd1, 3'b110, 5'd14);
    dut.imem.memory[13] = encode_r(7'b0000001, 5'd0, 5'd1, 3'b111, 5'd15);
    dut.imem.memory[14] = 32'hfff00813; // addi x16, x0, -1
    dut.imem.memory[15] = encode_r(7'b0000001, 5'd16, 5'd1, 3'b100, 5'd17);
    dut.imem.memory[16] = encode_r(7'b0000001, 5'd16, 5'd1, 3'b110, 5'd18);
    dut.imem.memory[17] = 32'h0000006f; // jal x0, 0
    repeat (2) @(posedge clk);
    reset = 1'b0;
    repeat (200) @(posedge clk);
    #1;

    if (dut.rf.registers[3] !== 32'd0)
        $fatal(1, "MUL incorrect: x3=%h", dut.rf.registers[3]);
    if (dut.rf.registers[4] !== 32'hffffffff)
        $fatal(1, "MULH incorrect: x4=%0d", dut.rf.registers[4]);
    if (dut.rf.registers[5] !== 32'hffffffff)
        $fatal(1, "MULHSU incorrect: x5=%0d", dut.rf.registers[5]);
    if (dut.rf.registers[6] !== 32'd1)
        $fatal(1, "MULHU incorrect: x6=%0d", dut.rf.registers[6]);
    if (dut.rf.registers[7] !== 32'hc0000000)
        $fatal(1, "DIV incorrect: x7=%0d", dut.rf.registers[7]);
    if (dut.rf.registers[8] !== 32'h40000000)
        $fatal(1, "DIVU incorrect: x8=%0d", dut.rf.registers[8]);
    if (dut.rf.registers[9] !== 32'd0)
        $fatal(1, "REM incorrect: x9=%0d", dut.rf.registers[9]);
    if (dut.rf.registers[10] !== 32'd0)
        $fatal(1, "REMU incorrect: x10=%0d", dut.rf.registers[10]);
    if (dut.rf.registers[12] !== 32'hffffffff ||
        dut.rf.registers[13] !== 32'hffffffff)
        $fatal(1, "Division by zero did not return all ones");
    if (dut.rf.registers[14] !== 32'h80000000 ||
        dut.rf.registers[15] !== 32'h80000000)
        $fatal(1, "Remainder by zero did not return the dividend");
    if (dut.rf.registers[17] !== 32'h80000000 ||
        dut.rf.registers[18] !== 32'd0)
        $fatal(1, "Signed division overflow behavior incorrect");

    reset = 1'b1;
    #1;
    dut.imem.memory[0] = 32'h301020f3; // csrrs x1, misa, x0
    dut.imem.memory[1] = 32'h0000006f; // jal x0, 0
    repeat (2) @(posedge clk);
    reset = 1'b0;
    repeat (40) @(posedge clk);
    #1;

    if (dut.rf.registers[1] !== 32'h40001102)
        $fatal(1, "misa does not report RV32IMB: misa=%h", dut.rf.registers[1]);

    @(negedge clk);
    reset = 1'b1;
    dut.imem.memory[0] = 32'hffffffff;
    repeat (2) @(negedge clk);
    reset = 1'b0;
    repeat (20) @(posedge clk);
    #1;

    if (last_trap_cause !== 32'd2)
        $fatal(1, "Illegal instruction trap incorrect: mcause=%h", last_trap_cause);

    $display("PASS: RV32I/RV32M operations, machine traps, and decoder rejection");
    $finish;
end

initial begin
    #100000;
    $fatal(1, "CPU testbench timed out");
end

endmodule
