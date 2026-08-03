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

    // Memory array (4096 x 32-bit words)
    reg [31:0] memory [0:TOTAL_MEM-1];

    // Bus state
    reg bus_busy;
    reg [31:0] pending_addr;
    reg pending_wr;

    // Initialize memory to zero
    initial begin
        for (int i = 0; i < TOTAL_MEM; i++) begin
            memory[i] = 0;
        end
    end

    // Ready signal (1 when idle)
    assign rdy = ~bus_busy;

    // Ack signal (1 when busy - transfer in progress)
    assign ack = bus_busy;

    // Read data output (valid when transfer complete)
    assign data_out = (bus_busy && ~pending_wr) ? memory[pending_addr] : 32'h0;

    // Bus handshake: 2-cycle latency
    // Cycle N: req asserted, memory accepts (bus_busy=1, stores pending)
    // Cycle N+1: memory performs transfer, ack=1
    always @(posedge clk) begin
        if (req && rdy) begin
            bus_busy = 1;
            pending_addr = addr;
            pending_wr = wr;
        end else if (bus_busy) begin
            if (pending_wr) begin
                memory[pending_addr] = data_in;
            end
            bus_busy = 0;
        end
    end

endmodule
