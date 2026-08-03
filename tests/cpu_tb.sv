/* verilator lint_off WIDTHEXPAND */
module cpu_tb;

    localparam PARAM_STACK   = 256;
    localparam PARAM_KTABLE  = 256;

    reg clk;
    reg reset;

    reg [31:0] bus_addr;
    reg [31:0] bus_data_out;
    wire [31:0] bus_data_in;
    reg bus_req;
    wire bus_ack;
    wire bus_rdy;
    reg bus_wr;

    wire error_flag;
    wire halt_flag;
    wire [7:0] error_code;

    integer cycle_count;
    integer test_passed;

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
        .uart_rx(0),
        .uart_tx(),
        .uart_tx_rdy(),
        .uart_rx_rdy(),
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

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        cycle_count = 0;
        test_passed = 0;
        reset = 1;
        repeat(10) @(posedge clk);
        reset = 0;
        @(posedge clk);

        // Preload instruction ROM
        // OP_MOVE A=1, B=0: R[1] = R[0] (key=0x00, A=1, B=0)
        cpu_inst.instr_rom_inst.rom_array[0] = 32'h00010000;
        // OP_LOADI A=2, sBx=512: R[2] = 512 (key=0x01, A=2, k=0, Bx=512)
        cpu_inst.instr_rom_inst.rom_array[1] = 32'h01020200;
        // OP_RETURN1 A=1: return R[1] (key=0x48=72, A=1)
        cpu_inst.instr_rom_inst.rom_array[2] = 32'h48010000;

        // Preload k-table at address PARAM_STACK (256)
        mem_inst.memory[PARAM_STACK] = 32'h00000064; // K[0] = 100

        $display("=== Test 1: OP_MOVE + OP_LOADI + OP_RETURN1 ===");

        repeat(300) begin
            @(posedge clk);
            cycle_count = cycle_count + 1;

            if (cycle_count >= 8 && cycle_count <= 50) begin
                $display("CYCLE %0d: pc=%0d bus_addr=%0h bus_data_out=%0h bus_req=%0b bus_wr=%0b halt=%0b err=%0b micro_active=%0b micro_done=%0b instr_a=%0h instr_decoded=%0b",
                    cycle_count, cpu_inst.pc, bus_addr, bus_data_out, bus_req, bus_wr, halt_flag, error_flag,
                    cpu_inst.microcode_active, cpu_inst.microcode_done, cpu_inst.instr_a, cpu_inst.instr_decoded);
            end

            if (halt_flag || error_flag) break;
        end

        $display("Stack[1]: %0h (expected 00000000 - OP_MOVE R[0]=0 to R[1])", mem_inst.memory[1]);
        $display("Stack[2]: %0h (expected 00000200 - OP_LOADI 512 = 0x200, lower 32 bits)", mem_inst.memory[2]);

        if (mem_inst.memory[1] == 32'h00000000 &&
            mem_inst.memory[2] == 32'h00000200) begin
            $display("TEST 1 PASSED");
            test_passed = test_passed + 1;
        end else begin
            $display("TEST 1 FAILED");
        end

        // Test 2: OP_LOADK, OP_LOADTRUE, OP_LOADFALSE, OP_LOADNIL
        reset = 1;
        repeat(10) @(posedge clk);
        reset = 0;
        @(posedge clk);
        cycle_count = 0;

        cpu_inst.instr_rom_inst.rom_array[0] = 32'h03000300; // OP_LOADK A=3, Bx=0 → R[3] = K[0] (key=3, A=3)
        cpu_inst.instr_rom_inst.rom_array[1] = 32'h07040000; // OP_LOADTRUE A=4 → R[4] = true (key=7, A=4)
        cpu_inst.instr_rom_inst.rom_array[2] = 32'h05050000; // OP_LOADFALSE A=5 → R[5] = false (key=5, A=5)
        cpu_inst.instr_rom_inst.rom_array[3] = 32'h08060000; // OP_LOADNIL A=6 → R[6] = nil (key=8, A=6)
        cpu_inst.instr_rom_inst.rom_array[4] = 32'h48000000; // OP_RETURN1 A=0 (key=72, halt)

        $display("=== Test 2: OP_LOADK + OP_LOADTRUE + OP_LOADFALSE + OP_LOADNIL ===");

        repeat(300) begin
            @(posedge clk);
            cycle_count = cycle_count + 1;

            if (cycle_count >= 8 && cycle_count <= 50) begin
                $display("CYCLE %0d: pc=%0d bus_addr=%0h bus_data_out=%0h bus_req=%0b bus_wr=%0b halt=%0b err=%0b",
                    cycle_count, cpu_inst.pc, bus_addr, bus_data_out, bus_req, bus_wr, halt_flag, error_flag);
            end

            if (halt_flag || error_flag) break;
        end

        $display("Stack[3]: %0h (expected 00000064 - OP_LOADK K[0]=100, lower 32 bits)", mem_inst.memory[3]);
        $display("Stack[4]: %0h (expected 00000001 - OP_LOADTRUE, lower 32 bits)", mem_inst.memory[4]);
        $display("Stack[5]: %0h (expected 00000000 - OP_LOADFALSE, lower 32 bits)", mem_inst.memory[5]);
        $display("Stack[6]: %0h (expected 00000000 - OP_LOADNIL, lower 32 bits)", mem_inst.memory[6]);

        if (mem_inst.memory[3] == 32'h00000064 &&
            mem_inst.memory[4] == 32'h00000001 &&
            mem_inst.memory[5] == 32'h00000000 &&
            mem_inst.memory[6] == 32'h00000000) begin
            $display("TEST 2 PASSED");
            test_passed = test_passed + 1;
        end else begin
            $display("TEST 2 FAILED");
        end

        $display("=== Test Results: %0d/2 passed ===", test_passed);
        $finish;
    end

    initial begin
        $dumpfile("trace.vcd");
        $dumpvars(0, cpu_tb);
    end

/* verilator lint_on WIDTHEXPAND */
endmodule
