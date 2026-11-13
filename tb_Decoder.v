`timescale 1ns/1ps

module tb_Decoder;

reg [31:0] instruction;
wire illegal_instruction;
wire is_r_type;
wire is_i_type;
wire is_u_type;
wire is_load;
wire is_store;
wire is_branch;
wire is_jal;
wire is_jalr;
wire is_fence;
wire is_csr;
wire is_ecall;
wire is_ebreak;
wire is_mret;

Decoder dut (
    .instruction(instruction),
    .illegal_instruction(illegal_instruction),
    .is_r_type(is_r_type),
    .is_i_type(is_i_type),
    .is_u_type(is_u_type),
    .is_load(is_load),
    .is_store(is_store),
    .is_branch(is_branch),
    .is_jal(is_jal),
    .is_jalr(is_jalr),
    .is_fence(is_fence),
    .is_csr(is_csr),
    .is_ecall(is_ecall),
    .is_ebreak(is_ebreak),
    .is_mret(is_mret)
);

task expect_fence;
    input [31:0] value;
    begin
        instruction = value;
        #1;
        if (illegal_instruction || !is_fence)
            $fatal(1, "Expected legal FENCE encoding %h", value);
    end
endtask

task expect_illegal;
    input [31:0] value;
    begin
        instruction = value;
        #1;
        if (!illegal_instruction)
            $fatal(1, "Expected illegal instruction %h", value);
    end
endtask

initial begin
    instruction = 32'b0;

    expect_fence(32'h0000000f);
    expect_fence(32'h8330000f);
    expect_fence(32'h0000100f);

    expect_illegal(32'h0000800f);
    expect_illegal(32'h0000008f);
    expect_illegal(32'h1000000f);
    expect_illegal(32'h8030000f);
    expect_illegal(32'h0010100f);
    expect_illegal(32'h0000900f);
    expect_illegal(32'h00000053);
    expect_illegal(32'h00003003);
    expect_illegal(32'h00003023);

    $display("PASS: FENCE validation and unsupported floating-point rejection");
    $finish;
end

initial begin
    #1000;
    $fatal(1, "Decoder testbench timed out");
end

endmodule
