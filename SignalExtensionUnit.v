`timescale 1ns/1ps

module SignalExtensionUnit (
    input wire [31:0] instruction,
    output wire [31:0] immediate_i,
    output wire [31:0] immediate_s,
    output wire [31:0] immediate_b,
    output wire [31:0] immediate_u,
    output wire [31:0] immediate_j
);

assign immediate_i = {{20{instruction[31]}}, instruction[31:20]};
assign immediate_s = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]};
assign immediate_b = {{19{instruction[31]}}, instruction[31], instruction[7],
                       instruction[30:25], instruction[11:8], 1'b0};
assign immediate_u = {instruction[31:12], 12'b0};
assign immediate_j = {{11{instruction[31]}}, instruction[31], instruction[19:12],
                       instruction[20], instruction[30:21], 1'b0};

endmodule
