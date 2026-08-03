module mem_model #(
    parameter TOTAL_MEM = 4096
)(
    input  wire clk,
    input  wire [31:0] addr,
    input  wire [31:0] data_in,
    output wire [31:0] data_out,
    input  wire req,
    output wire ack,
    output wire rdy,
    input  wire wr
);

    reg [31:0] memory [0:TOTAL_MEM-1];

    initial begin
        for (int i = 0; i < TOTAL_MEM; i++) begin
            memory[i] = 0;
        end
    end

    assign rdy = 1'b1;
    assign ack = req;
    assign data_out = (~wr) ? memory[addr] : 32'h0;

    always @(posedge clk) begin
        if (req) begin
            if (wr) begin
                memory[addr] = data_in;
            end
        end
    end

endmodule
