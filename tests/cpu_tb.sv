/* verilator lint_off WIDTHEXPAND */
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
    reg [63:0] expected_r1;
    reg [63:0] expected_r2;
    reg [63:0] expected_r3;
    reg [63:0] actual_r1;
    reg [63:0] actual_r2;
    reg [63:0] actual_r3;

    // Instruction ROM preload data
    reg [31:0] instr_rom_data_test;
    reg [31:0] ktable_data_test;

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

        // Preload instruction ROM
        // OP_MOVE A=1, B=0: R[1] = R[0]
        // Encoding 1: A=1, B=0, C=0, k=0, key=0
        // ir[31:24]=1, ir[23:16]=0, ir[15:8]=0, ir[6]=0, ir[22:16]=0
        cpu_inst.instr_rom_inst.rom_array[0] = 32'h01_00_00_00;

        // OP_LOADI A=2, sBx=512 (positive)
        // Encoding 2: A=2, key=1, Bx[16]=0, Bx[15:9]=1, Bx[8:1]=0, Bx[0]=0
        // ir[31:24]=2, ir[23]=0, ir[22:16]=1, ir[15:8]=0, ir[7]=0, ir[6]=0
        cpu_inst.instr_rom_inst.rom_array[1] = 32'h02_01_00_00;

        // OP_LOADK A=3, Bx=0 (k-table index 0)
        // key=3, B=3 (lower 7 bits = 3), C=0, ir[7]=0
        // ir[31:24]=3, ir[23]=0, ir[22:16]=3, ir[15:8]=0, ir[7]=0, ir[6]=0
        cpu_inst.instr_rom_inst.rom_array[2] = 32'h03_03_00_00;

        // OP_RETURN1 A=3: return R[3]
        // key=0x48, A=3, B=2, C=0, k=0
        // ir[31:24]=3, ir[23:16]=2, ir[15:8]=0, ir[6]=0, ir[22:16]=0x48
        cpu_inst.instr_rom_inst.rom_array[3] = 32'h03_02_00_48;

        // Preload k-table: K[0] = NaN-boxed integer 100
        // k-table starts at PARAM_STACK = 256
        // K[0] at address 256: 32'h00000064
        mem_inst.memory[PARAM_STACK] = 32'h00000064;

        // Preload stack: R[0] = 0 (already zero from initialization)

        repeat(10) begin
            @(posedge clk);
            cycle_count = cycle_count + 1;
        end

        reset = 0;
        @(posedge clk);
        cycle_count = cycle_count + 1;

        // Wait for execution to complete
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

        // Verify results
        expected_r1 = {12'hfff, 20'hffff0, 32'h00000000}; // NaN-boxed integer 0
        expected_r2 = {12'hfff, 20'hffff0, 32'h00000200}; // NaN-boxed integer 512
        expected_r3 = {12'hfff, 20'hffff0, 32'h00000064}; // NaN-boxed integer 100 (from K[0])

        // Read register cache contents by triggering reads
        // We check by observing bus writes to stack addresses
        // R[1] at stack addr 1, R[2] at stack addr 2, R[3] at stack addr 3

        $display("=== Test Results ===");
        $display("Total cycles: %0d", cycle_count);
        $display("error_flag: %0b", error_flag);
        $display("halt_flag: %0b", halt_flag);
        $display("Expected R[1]: %0h (NaN-boxed int 0)", expected_r1);
        $display("Expected R[2]: %0h (NaN-boxed int 512)", expected_r2);
        $display("Expected R[3]: %0h (NaN-boxed int 100)", expected_r3);

        // Check stack memory for written values
        $display("Stack[1]: %0h", mem_inst.memory[1]);
        $display("Stack[2]: %0h", mem_inst.memory[2]);
        $display("Stack[3]: %0h", mem_inst.memory[3]);

        if (mem_inst.memory[1] == 32'h00000000 &&
            mem_inst.memory[2] == 32'h00000200 &&
            mem_inst.memory[3] == 32'h00000064) begin
            $display("TEST PASSED");
            test_passed = 1;
        end else begin
            $display("TEST FAILED - register values do not match expected");
            test_passed = 0;
            test_failed = 1;
        end

        $finish;
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

/* verilator lint_on WIDTHEXPAND */
endmodule
