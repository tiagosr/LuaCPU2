module cpu_tb;

    // Parameters
    localparam PARAM_STACK   = 256;
    localparam PARAM_KTABLE  = 256;
    localparam PARAM_PROTOS  = 256;
    localparam PARAM_UPVALUES = 128;
    localparam PARAM_TOTALMEM = 4096;
    localparam PARAM_ROMSIZE  = 4096;

    // Clock and reset
    reg clk;
    reg reset;

    // Bus signals (CPU -> external)
    reg [31:0] bus_addr;
    reg [31:0] bus_data_out;
    wire [31:0] bus_data_in;
    reg bus_req;
    wire bus_ack;
    wire bus_rdy;
    reg bus_wr;

    // UART signals
    reg uart_rx;
    wire uart_tx;
    wire uart_tx_rdy;
    wire uart_rx_rdy;

    // Status signals
    wire error_flag;
    wire halt_flag;
    wire [7:0] error_code;

    // Cycle counter
    integer cycle_count;
    integer instr_count;

    // UART capture
    reg [7:0] uart_tx_char;
    integer uart_tx_count;
    reg uart_tx_valid;

    // Test results
    reg test_passed;
    reg test_failed;

    // Instantiate CPU
    cpu cpu_inst (
        .clk(clk),
        .reset(reset),
        .bus_addr(bus_addr),
        .bus_data_out(bus_data_out),
        .bus_data_in(bus_data_in),
        .bus_req(bus_req),
        .bus_ack(bus_ack),
        .bus_rdy(bus_rdy),
        .bus_wr(bus_wr),
        .uart_rx(uart_rx),
        .uart_tx(uart_tx),
        .uart_tx_rdy(uart_tx_rdy),
        .uart_rx_rdy(uart_rx_rdy),
        .error_flag(error_flag),
        .halt_flag(halt_flag),
        .error_code(error_code)
    );

    // Instantiate external memory model
    mem_model mem_inst (
        .clk(clk),
        .addr(bus_addr),
        .data_in(bus_data_out),
        .data_out(bus_data_in),
        .req(bus_req),
        .ack(bus_ack),
        .rdy(bus_rdy),
        .wr(bus_wr)
    );

    // Instantiate UART model
    uart_model uart_inst (
        .clk(clk),
        .rx(uart_rx),
        .tx(uart_tx),
        .tx_rdy(uart_tx_rdy),
        .rx_rdy(uart_rx_rdy)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Reset and test sequence
    initial begin
        cycle_count = 0;
        instr_count = 0;
        uart_tx_count = 0;
        test_passed = 1;
        test_failed = 0;
        uart_rx = 0;

        // Assert reset for 10 cycles
        reset = 1;
        bus_req = 0;
        bus_wr = 0;
        bus_addr = 0;
        bus_data_out = 0;

        repeat(10) begin
            @(posedge clk);
            cycle_count = cycle_count + 1;
        end

        // Deassert reset
        reset = 0;
        @(posedge clk);
        cycle_count = cycle_count + 1;

        // Wait for CPU to start executing
        repeat(20) begin
            @(posedge clk);
            cycle_count = cycle_count + 1;
        end

        // Monitor for completion or error
        repeat(500) begin
            @(posedge clk);
            cycle_count = cycle_count + 1;

            if (halt_flag) begin
                break;
            end

            if (error_flag) begin
                test_passed = 0;
                test_failed = 1;
                $display("ERROR: error_flag asserted at cycle %0d, error_code = %0h", cycle_count, error_code);
                break;
            end
        end

        // Final assertions
        // Reset behavior: after reset deassertion, error_flag should be 0 initially
        $display("=== Test Results ===");
        $display("Total cycles: %0d", cycle_count);
        $display("UART characters transmitted: %0d", uart_tx_count);
        $display("error_flag: %0b", error_flag);
        $display("halt_flag: %0b", halt_flag);

        if (test_passed) begin
            $display("TEST PASSED");
            $finish;
        end else begin
            $display("TEST FAILED");
            $finish;
        end
    end

    // UART tx capture
    always @(posedge clk) begin
        if (uart_tx_rdy && uart_tx_valid) begin
            uart_tx_count = uart_tx_count + 1;
        end
    end

    // VCD tracing
    initial begin
        $dumpfile("trace.vcd");
        $dumpvars(0, cpu_tb);
    end

    // Assertion: reset should hold error_flag and halt_flag low
    initial begin
        @(posedge clk); // first cycle after reset asserted
        assert (error_flag == 0) else $display("ASSERT FAIL: error_flag should be 0 during reset");
        assert (halt_flag == 0) else $display("ASSERT FAIL: halt_flag should be 0 during reset");
    end

endmodule
