module cpu #(
    parameter PARAM_STACK   = 256,
    parameter PARAM_KTABLE  = 256,
    parameter PARAM_PROTOS  = 256,
    parameter PARAM_UPVALUES = 128,
    parameter PARAM_TOTALMEM = 4096,
    parameter PARAM_ROMSIZE  = 4096
)(
    input  wire clk,
    input  wire reset,
    output reg [31:0] bus_addr,
    output reg [31:0] bus_data_out,
    input  wire [31:0] bus_data_in,
    output reg bus_req,
    output reg bus_ack,
    input  wire bus_rdy,
    output reg bus_wr,
    input  wire uart_rx,
    output reg uart_tx,
    output reg uart_tx_rdy,
    input  wire uart_rx_rdy,
    output reg error_flag,
    output reg halt_flag,
    output reg [7:0] error_code
);

    // PC register
    reg [31:0] pc;

    // Instruction register
    reg [31:0] ir;

    // Window base register
    reg [31:0] wb;

    // Stack pointer
    reg [31:0] stack_ptr;

    // Top marker
    reg [31:0] top;

    // Microcode sequencer state
    reg [9:0] micro_idx;
    reg micro_active;

    // Bus controller state
    reg bus_state_idle;
    reg bus_state_req;
    reg bus_state_wait;
    reg bus_state_ack;

    // GC state
    reg gc_state_idle;
    reg [31:0] alloc_counter;

    // UART FIFO state
    reg [7:0] uart_tx_fifo [0:15];
    reg uart_tx_fifo_count;

    // Prefetch state
    reg [31:0] prefetch_pc;
    reg [31:0] prefetch_ir;
    reg prefetch_valid;

    // Reset behavior
    initial begin
        if (reset) begin
            pc = 0;
            ir = 0;
            wb = 0;
            stack_ptr = 0;
            top = 0;
            micro_idx = 0;
            micro_active = 0;
            bus_state_idle = 1;
            bus_state_req = 0;
            bus_state_wait = 0;
            bus_state_ack = 0;
            bus_addr = 0;
            bus_data_out = 0;
            bus_req = 0;
            bus_ack = 0;
            bus_wr = 0;
            error_flag = 0;
            halt_flag = 0;
            error_code = 0;
            gc_state_idle = 1;
            alloc_counter = 0;
            uart_tx_fifo_count = 0;
            prefetch_pc = 1;
            prefetch_ir = 0;
            prefetch_valid = 0;
            uart_tx = 1;
            uart_tx_rdy = 1;
        end
    end

    // Main state machine
    always @(posedge clk) begin
        if (reset) begin
            // Reset handled by initial block
        end else if (halt_flag) begin
            // CPU halted - hold state
            bus_req = 0;
        end else if (error_flag) begin
            // CPU in error state - hold state
            bus_req = 0;
        end else begin
            // Normal operation stub
            // Prefetch unit: fetch next instruction from ROM
            prefetch_pc = pc + 1;
            prefetch_ir = 0; // ROM not implemented yet
            prefetch_valid = 1;

            // Bus controller: idle state
            bus_state_idle = 1;
            bus_state_req = 0;
            bus_state_wait = 0;
            bus_state_ack = 0;
            bus_req = 0;
            bus_addr = pc;

            // Microcode sequencer: idle
            micro_active = 0;
            micro_idx = 0;

            // GC: idle
            gc_state_idle = 1;
        end
    end

endmodule
