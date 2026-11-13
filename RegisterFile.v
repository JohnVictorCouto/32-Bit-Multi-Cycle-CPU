`timescale 1ns/1ps

module RegisterFile (
    input wire clk,
    input wire reset,
    input wire [4:0] read_address1,
    input wire [4:0] read_address2,
    output wire [31:0] read_data1,
    output wire [31:0] read_data2,
    input wire write_enable,
    input wire [4:0] write_address,
    input wire [31:0] write_data
);

reg [31:0] registers [0:31];
integer i;

assign read_data1 = (read_address1 == 5'b0) ? 32'b0 : registers[read_address1];
assign read_data2 = (read_address2 == 5'b0) ? 32'b0 : registers[read_address2];

always @(posedge clk) begin
    if (reset) begin
        for (i = 0; i < 32; i = i + 1)
            registers[i] <= 32'b0;
    end else begin
        registers[0] <= 32'b0;
        if (write_enable && (write_address != 5'b0))
            registers[write_address] <= write_data;
    end
end

endmodule
