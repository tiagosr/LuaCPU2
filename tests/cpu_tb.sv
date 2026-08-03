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
        reset = 1;
        repeat(10) @(posedge clk);
        reset = 0;
        @(posedge clk);

        // Preload instruction ROM
        // OP_MOVE A=1, B=0: R[1] = R[0]
        cpu_inst.instr_rom_inst.rom_array[0] = 32'h01_00_00_00;
        // OP_LOADI A=2, sBx=512
        cpu_inst.instr_rom_inst.rom_array[1] = 32'h02_01_00_00;
        // OP_RETURN1 A=3: halt
        cpu_inst.instr_rom_inst.rom_array[2] = 32'h03_02_00_48;

        // Preload k-table
        mem_inst.memory[PARAM_STACK] = 32'h00000064;

        $display("=== Simple Test: OP_MOVE + OP_LOADI ===");

        repeat(200) begin
            @(posedge clk);
            cycle_count = cycle_count + 1;

            if (cycle_count >= 12 && cycle_count <= 25) begin
                $display("CYCLE %0d: pc=%0d bus_addr=%0h bus_data_out=%0h bus_req=%0b bus_wr=%0b halt=%0b err=%0b",
                    cycle_count, cpu_inst.pc, bus_addr, bus_data_out, bus_req, bus_wr, halt_flag, error_flag);
            end

            if (halt_flag || error_flag) break;
        end

        $display("Stack[1]: %0h (expected 00000000)", mem_inst.memory[1]);
        $display("Stack[2]: %0h (expected 00000200)", mem_inst.memory[2]);

        if (mem_inst.memory[1] == 32'h00000000 && mem_inst.memory[2] == 32'h00000200) begin
            $display("TEST PASSED");
        end else begin
            $display("TEST FAILED");
        end

        $finish;
    end

    initial begin
        $dumpfile("trace.vcd");
        $dumpvars(0, cpu_tb);
    end

/* verilator lint_on WIDTHEXPAND */
endmodule
