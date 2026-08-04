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

        // Preload instruction ROM before reset
        cpu_inst.instr_rom_inst.rom_array[0] = 32'h00000100;
        cpu_inst.instr_rom_inst.rom_array[1] = 32'h01010200;
        cpu_inst.instr_rom_inst.rom_array[2] = 32'h48000000;

        // Preload k-table at address PARAM_STACK (256)
        mem_inst.memory[PARAM_STACK] = 32'h00000064;

        reset = 1;
        repeat(10) @(posedge clk);
        reset = 0;
        @(posedge clk);

        $display("=== Test 1: OP_MOVE + OP_LOADI + OP_RETURN1 ===");

        repeat(300) begin
            @(posedge clk);
            cycle_count = cycle_count + 1;

            if (cycle_count >= 8 && cycle_count <= 50) begin
                $display("CYCLE %0d: pc=%0d bus_addr=%0h bus_data_out=%0h bus_req=%0b bus_wr=%0b halt=%0b err=%0b",
                    cycle_count, cpu_inst.pc, bus_addr, bus_data_out, bus_req, bus_wr, halt_flag, error_flag);
                $display("  WB_READY=%0b",
                    cpu_inst.writeback_ready);
                $display("  microcode_alu_op=%0h microcode_operand_a_sel=%0h microcode_operand_b_sel=%0h",
                    cpu_inst.microcode_rom_inst.alu_op, cpu_inst.microcode_rom_inst.operand_a_sel, cpu_inst.microcode_rom_inst.operand_b_sel);
                $display("  bus_idle=%0b bus_request=%0b bus_wait=%0b bus_writeback=%0b reg_cache_stall=%0b ktable_waiting=%0b",
                    cpu_inst.bus_idle, cpu_inst.bus_request, cpu_inst.bus_wait, cpu_inst.bus_writeback, cpu_inst.reg_cache_inst.stall, cpu_inst.ktable_waiting);
                $display("  alu_result_valid=%0b ktable_valid=%0b reg_cache_read_valid=%0b value_conv_valid=%0b",
                    cpu_inst.alu_inst.result_valid, cpu_inst.ktable_valid, cpu_inst.reg_cache_inst.read_valid, cpu_inst.value_conv_inst.load_value_valid);
                $display("  b_operand_pipe=%0h ktable_data=%0h alu_result=%0h value_conv_load_value=%0h instr_a=%0h",
                    cpu_inst.b_operand_pipe, cpu_inst.ktable_data, cpu_inst.alu_result, cpu_inst.value_conv_inst.load_value, cpu_inst.instr_a);
                $display("  operand_offset=%0h operand_c_offset=%0h reg_cache_cache_miss=%0b",
                    cpu_inst.reg_cache_inst.operand_offset, cpu_inst.reg_cache_inst.operand_c_offset, cpu_inst.reg_cache_inst.cache_miss);
                $display("  instr_a=%0h instr_b=%0h instr_c=%0h", cpu_inst.instr_a, cpu_inst.instr_b, cpu_inst.instr_c);
                $display("  stack_ptr_wb=%0h stack_addr=%0h", cpu_inst.stack_ptr_wb, cpu_inst.reg_cache_inst.stack_addr);
            end

            if (halt_flag || error_flag) break;
        end

        $display("Stack[0]: %0h (expected 00000000 - OP_MOVE R[0]=R[1]=0)", mem_inst.memory[0]);
        $display("Stack[1]: %0h (expected 00000200 - OP_LOADI R[1]=512=0x200)", mem_inst.memory[1]);

        if (mem_inst.memory[0] == 32'h00000000 &&
            mem_inst.memory[1] == 32'h00000200) begin
            $display("TEST 1 PASSED");
            test_passed = test_passed + 1;
        end else begin
            $display("TEST 1 FAILED");
        end

        // Test 2: OP_LOADK, OP_LOADTRUE, OP_LOADFALSE, OP_LOADNIL
        cpu_inst.instr_rom_inst.rom_array[0] = 32'h03000000;
        cpu_inst.instr_rom_inst.rom_array[1] = 32'h07000000;
        cpu_inst.instr_rom_inst.rom_array[2] = 32'h05000000;
        cpu_inst.instr_rom_inst.rom_array[3] = 32'h08000000;
        cpu_inst.instr_rom_inst.rom_array[4] = 32'h48000000;
        reset = 1;
        repeat(10) @(posedge clk);
        reset = 0;
        @(posedge clk);
        cycle_count = 0;

        $display("=== Test 2: OP_LOADK + OP_LOADTRUE + OP_LOADFALSE + OP_LOADNIL ===");

        repeat(300) begin
            @(posedge clk);
            cycle_count = cycle_count + 1;

            if (cycle_count >= 8 && cycle_count <= 50) begin
                $display("CYCLE %0d: pc=%0d bus_addr=%0h bus_data_out=%0h bus_req=%0b bus_wr=%0b halt=%0b err=%0b",
                    cycle_count, cpu_inst.pc, bus_addr, bus_data_out, bus_req, bus_wr, halt_flag, error_flag);
                $display("  WB_READY=%0b",
                    cpu_inst.writeback_ready);
                $display("  microcode_alu_op=%0h microcode_operand_a_sel=%0h microcode_operand_b_sel=%0h",
                    cpu_inst.microcode_rom_inst.alu_op, cpu_inst.microcode_rom_inst.operand_a_sel, cpu_inst.microcode_rom_inst.operand_b_sel);
                $display("  bus_idle=%0b bus_request=%0b bus_wait=%0b bus_writeback=%0b reg_cache_stall=%0b ktable_waiting=%0b",
                    cpu_inst.bus_idle, cpu_inst.bus_request, cpu_inst.bus_wait, cpu_inst.bus_writeback, cpu_inst.reg_cache_inst.stall, cpu_inst.ktable_waiting);
                $display("  alu_result_valid=%0b ktable_valid=%0b reg_cache_read_valid=%0b value_conv_valid=%0b",
                    cpu_inst.alu_inst.result_valid, cpu_inst.ktable_valid, cpu_inst.reg_cache_inst.read_valid, cpu_inst.value_conv_inst.load_value_valid);
                $display("  b_operand_pipe=%0h ktable_data=%0h alu_result=%0h value_conv_load_value=%0h instr_a=%0h",
                    cpu_inst.b_operand_pipe, cpu_inst.ktable_data, cpu_inst.alu_result, cpu_inst.value_conv_inst.load_value, cpu_inst.instr_a);
            end

            if (halt_flag || error_flag) break;
        end

        $display("Stack[3]: %0h (expected 00000064 - OP_LOADK R[3]=K[0]=100)", mem_inst.memory[3]);
        $display("Stack[7]: %0h (expected 00000001 - OP_LOADTRUE R[7]=true)", mem_inst.memory[7]);
        $display("Stack[5]: %0h (expected 00000000 - OP_LOADFALSE R[5]=false)", mem_inst.memory[5]);
        $display("Stack[8]: %0h (expected 00000000 - OP_LOADNIL R[8]=nil)", mem_inst.memory[8]);

        if (mem_inst.memory[3] == 32'h00000064 &&
            mem_inst.memory[7] == 32'h00000001 &&
            mem_inst.memory[5] == 32'h00000000 &&
            mem_inst.memory[8] == 32'h00000000) begin
            $display("TEST 2 PASSED");
            test_passed = test_passed + 1;
        end else begin
            $display("TEST 2 FAILED");
        end

        // Test 3: OP_ADD two-operand
        cpu_inst.instr_rom_inst.rom_array[0] = 32'h00000100;
        cpu_inst.instr_rom_inst.rom_array[1] = 32'h01010200;
        cpu_inst.instr_rom_inst.rom_array[2] = 32'h0E0E0102;
        cpu_inst.instr_rom_inst.rom_array[3] = 32'h48000000;
        reset = 1;
        repeat(10) @(posedge clk);
        reset = 0;
        @(posedge clk);
        cycle_count = 0;

        $display("=== Test 3: OP_ADD two-operand ===");

        repeat(300) begin
            @(posedge clk);
            cycle_count = cycle_count + 1;

            if (cycle_count >= 8 && cycle_count <= 80) begin
                $display("CYCLE %0d: pc=%0d bus_addr=%0h bus_data_out=%0h bus_req=%0b bus_wr=%0b halt=%0b err=%0b",
                    cycle_count, cpu_inst.pc, bus_addr, bus_data_out, bus_req, bus_wr, halt_flag, error_flag);
                $display("  WB_READY=%0b",
                    cpu_inst.writeback_ready);
                $display("  microcode_alu_op=%0h microcode_operand_a_sel=%0h microcode_operand_b_sel=%0h",
                    cpu_inst.microcode_rom_inst.alu_op, cpu_inst.microcode_rom_inst.operand_a_sel, cpu_inst.microcode_rom_inst.operand_b_sel);
                $display("  bus_idle=%0b bus_request=%0b bus_wait=%0b bus_writeback=%0b reg_cache_stall=%0b ktable_waiting=%0b",
                    cpu_inst.bus_idle, cpu_inst.bus_request, cpu_inst.bus_wait, cpu_inst.bus_writeback, cpu_inst.reg_cache_inst.stall, cpu_inst.ktable_waiting);
                $display("  alu_result_valid=%0b ktable_valid=%0b reg_cache_read_valid=%0b value_conv_valid=%0b",
                    cpu_inst.alu_inst.result_valid, cpu_inst.ktable_valid, cpu_inst.reg_cache_inst.read_valid, cpu_inst.value_conv_inst.load_value_valid);
                $display("  b_operand_pipe=%0h ktable_data=%0h alu_result=%0h value_conv_load_value=%0h instr_a=%0h",
                    cpu_inst.b_operand_pipe, cpu_inst.ktable_data, cpu_inst.alu_result, cpu_inst.value_conv_inst.load_value, cpu_inst.instr_a);
            end

            if (halt_flag || error_flag) break;
        end

        $display("Stack[14]: %0h (expected 00000200 - OP_ADD R[1]+R[2]=512+0=512)", mem_inst.memory[14]);

        if (mem_inst.memory[14] == 32'h00000200) begin
            $display("TEST 3 PASSED");
            test_passed = test_passed + 1;
        end else begin
            $display("TEST 3 FAILED");
        end

        // Test 4: OP_ADDK k-table operand
        mem_inst.memory[PARAM_STACK + 3] = 32'h00000064;
        cpu_inst.instr_rom_inst.rom_array[0] = 32'h00000100;
        cpu_inst.instr_rom_inst.rom_array[1] = 32'h16022300;
        cpu_inst.instr_rom_inst.rom_array[2] = 32'h48000000;
        reset = 1;
        repeat(10) @(posedge clk);
        reset = 0;
        @(posedge clk);
        cycle_count = 0;

        $display("=== Test 4: OP_ADDK k-table operand ===");

        repeat(300) begin
            @(posedge clk);
            cycle_count = cycle_count + 1;

            if (cycle_count >= 8 && cycle_count <= 100) begin
                $display("CYCLE %0d: pc=%0d bus_addr=%0h bus_data_out=%0h bus_req=%0b bus_wr=%0b halt=%0b err=%0b",
                    cycle_count, cpu_inst.pc, bus_addr, bus_data_out, bus_req, bus_wr, halt_flag, error_flag);
                $display("  WB_READY=%0b",
                    cpu_inst.writeback_ready);
                $display("  microcode_alu_op=%0h microcode_operand_a_sel=%0h microcode_operand_b_sel=%0h",
                    cpu_inst.microcode_rom_inst.alu_op, cpu_inst.microcode_rom_inst.operand_a_sel, cpu_inst.microcode_rom_inst.operand_b_sel);
                $display("  bus_idle=%0b bus_request=%0b bus_wait=%0b bus_writeback=%0b reg_cache_stall=%0b ktable_waiting=%0b",
                    cpu_inst.bus_idle, cpu_inst.bus_request, cpu_inst.bus_wait, cpu_inst.bus_writeback, cpu_inst.reg_cache_inst.stall, cpu_inst.ktable_waiting);
                $display("  alu_result_valid=%0b ktable_valid=%0b reg_cache_read_valid=%0b value_conv_valid=%0b",
                    cpu_inst.alu_inst.result_valid, cpu_inst.ktable_valid, cpu_inst.reg_cache_inst.read_valid, cpu_inst.value_conv_inst.load_value_valid);
                $display("  b_operand_pipe=%0h ktable_data=%0h alu_result=%0h value_conv_load_value=%0h instr_a=%0h",
                    cpu_inst.b_operand_pipe, cpu_inst.ktable_data, cpu_inst.alu_result, cpu_inst.value_conv_inst.load_value, cpu_inst.instr_a);
            end

            if (halt_flag || error_flag) break;
        end

        $display("Stack[22]: %0h (expected 00000064 - OP_ADDK R[2]+K[3]=0+100=100)", mem_inst.memory[22]);

        if (mem_inst.memory[22] == 32'h00000064) begin
            $display("TEST 4 PASSED");
            test_passed = test_passed + 1;
        end else begin
            $display("TEST 4 FAILED");
        end

        $display("=== Test Results: %0d/4 passed ===", test_passed);
        $finish;
    end

    initial begin
        $dumpfile("trace.vcd");
        $dumpvars(0, cpu_tb);
    end

/* verilator lint_on WIDTHEXPAND */
endmodule
