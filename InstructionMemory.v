`timescale 1ns/1ps

module InstructionMemory #(
    parameter integer WORDS = 256,
    parameter INIT_FILE = ""
) (
    input wire [31:0] address,
    output reg [31:0] instruction
);

reg [31:0] memory [0:WORDS-1];
integer i;

initial begin
    for (i = 0; i < WORDS; i = i + 1)
        memory[i] = 32'h00000013;
    if (INIT_FILE != "")
        $readmemh(INIT_FILE, memory);
end

always @* begin
    if ((address[31:2] < WORDS) && (address[1:0] == 2'b00))
        instruction = memory[address[31:2]];
    else
        instruction = 32'h00000013;
end

endmodule
