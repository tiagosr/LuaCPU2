module instr_rom #(
    parameter ROM_SIZE = 4096
)(
    input  wire clk,
    input  wire [31:0] address,
    output wire [31:0] data
);

    reg [31:0] rom_array [0:ROM_SIZE-1];

    initial begin
        for (integer i = 0; i < ROM_SIZE; i = i + 1) begin
            rom_array[i] = 32'h0;
        end
    end

    assign data = rom_array[address];

endmodule
