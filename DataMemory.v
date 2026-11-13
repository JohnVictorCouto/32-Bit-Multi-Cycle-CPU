`timescale 1ns/1ps

module DataMemory #(
    parameter integer BYTES = 1024,
    parameter INIT_FILE = ""
) (
    input wire clk,
    input wire [31:0] address,
    input wire [31:0] write_data,
    input wire [1:0] write_size,
    input wire write_enable,
    output reg [31:0] read_word
);

reg [7:0] memory [0:BYTES-1];
wire [31:0] aligned_address = {address[31:2], 2'b00};
integer i;

initial begin
    for (i = 0; i < BYTES; i = i + 1)
        memory[i] = 8'b0;
    if (INIT_FILE != "")
        $readmemh(INIT_FILE, memory);
end

always @* begin
    read_word = 32'b0;
    if (aligned_address < BYTES) begin
        read_word[7:0] = memory[aligned_address];
        if ((aligned_address + 1) < BYTES)
            read_word[15:8] = memory[aligned_address + 1];
        if ((aligned_address + 2) < BYTES)
            read_word[23:16] = memory[aligned_address + 2];
        if ((aligned_address + 3) < BYTES)
            read_word[31:24] = memory[aligned_address + 3];
    end
end

always @(posedge clk) begin
    if (write_enable) begin
        case (write_size)
            2'd0:
                memory[address] <= write_data[7:0];
            2'd1: begin
                memory[address] <= write_data[7:0];
                memory[address + 1] <= write_data[15:8];
            end
            2'd2: begin
                memory[address] <= write_data[7:0];
                memory[address + 1] <= write_data[15:8];
                memory[address + 2] <= write_data[23:16];
                memory[address + 3] <= write_data[31:24];
            end
            default: begin
            end
        endcase
    end
end

endmodule
