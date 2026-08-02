module cpu_tb;

    localparam PARAM_STACK   = 256;
    localparam PARAM_KTABLE  = 256;
    localparam PARAM_PROTOS  = 256;
    localparam PARAM_UPVALUES = 128;
    localparam PARAM_TOTALMEM = 4096;
    localparam PARAM_ROMSIZE  = 4096;

    reg clk;
    reg reset;

    reg [31:0] bus_addr;
    reg [31:0] bus_data_out;
    wire [31:0] bus_data_in;
    reg bus_req;
    wire bus_ack;
    wire bus_rdy;
    reg bus_wr;

    reg uart_rx;
    wire uart_tx;
    wire uart_tx_rdy;
    wire uart_rx_rdy;

    wire error_flag;
    wire halt_flag;
    wire [7:0] error_code;

    integer cycle_count;
    reg test_passed;
    reg test_failed;

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

    uart_model uart_inst (
        .clk(clk),
        .rx(uart_rx),
        .tx(uart_tx),
        .tx_rdy(uart_tx_rdy),
        .rx_rdy(uart_rx_rdy)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        cycle_count = 0;
        test_passed = 1;
        test_failed = 0;
        uart_rx = 0;

        reset = 1;
        bus_req = 0;
        bus_wr = 0;
        bus_addr = 0;
        bus_data_out = 0;

        repeat(10) begin
            @(posedge clk);
            cycle_count = cycle_count + 1;
        end

        reset = 0;
        @(posedge clk);
        cycle_count = cycle_count + 1;

        repeat(200) begin
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

        $display("=== Test Results ===");
        $display("Total cycles: %0d", cycle_count);
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

    initial begin
        $dumpfile("trace.vcd");
        $dumpvars(0, cpu_tb);
    end

    initial begin
        @(posedge clk);
        assert (error_flag == 0) else $display("ASSERT FAIL: error_flag should be 0 during reset");
        assert (halt_flag == 0) else $display("ASSERT FAIL: halt_flag should be 0 during reset");
    end

endmodule
