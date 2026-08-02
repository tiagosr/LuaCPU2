module instr_rom #(
    parameter ROM_DEPTH = 4096,
    parameter ROM_WIDTH = 32
)(
    input  wire clk,
    input  wire [31:0] address,
    output wire [ROM_WIDTH-1:0] data
);

    reg [ROM_WIDTH-1:0] rom_array [0:ROM_DEPTH-1];

    initial begin
        for (int i = 0; i < ROM_DEPTH; i++) begin
            rom_array[i] = 32'h0;
        end
    end

    assign data = rom_array[address];

endmodule
