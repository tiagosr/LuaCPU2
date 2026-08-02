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
    input  wire bus_ack,
    input  wire bus_rdy,
    output reg bus_wr,
    input  wire uart_rx,
    input  wire uart_tx,
    input  wire uart_tx_rdy,
    input  wire uart_rx_rdy,
    output reg error_flag,
    output reg halt_flag,
    output reg [7:0] error_code
);

    // PC register
    reg [31:0] pc;

    // Instruction register
    reg [31:0] ir;

    // Instruction operand fields
    reg [7:0] instr_a;
    reg [7:0] instr_b;
    reg [7:0] instr_c;
    reg [16:0] instr_bx;
    reg instr_k;
    reg [6:0] opcode_key;

    // Bus controller state
    reg bus_state_idle;
    reg bus_state_req;
    reg bus_state_wait;

    // GC state
    reg gc_state_idle;
    reg [31:0] alloc_counter;

    // UART FIFO state
    reg [7:0] uart_tx_fifo [0:15];
    reg uart_tx_fifo_count;

    // Microcode ROM address
    wire [9:0] microcode_rom_addr;

    // Register cache interface
    wire [63:0] reg_cache_read_data;
    wire reg_cache_read_valid;
    wire reg_cache_cache_miss;
    wire reg_cache_stall;
    wire reg_cache_write_bus_req;
    wire [31:0] reg_cache_write_bus_addr;
    wire [63:0] reg_cache_write_bus_data;

    // Microcode ROM interface
    wire [63:0] microcode_rom_data;

    // Microcode sequencer interface
    wire [4:0] microcode_alu_op;
    wire [3:0] microcode_reg_a_write;
    wire [3:0] microcode_reg_b_read;
    wire [3:0] microcode_reg_c_read;
    wire [2:0] microcode_mem_op;
    wire [2:0] microcode_pc_op;
    wire [1:0] microcode_micro_branch;
    wire [1:0] microcode_gc_step;
    wire [1:0] microcode_stack_op;
    wire microcode_enable;
    wire [33:0] microcode_immediate;
    wire microcode_micro_active;
    wire microcode_micro_done;
    wire [9:0] microcode_branch_target;

    // Stack pointer interface
    wire [31:0] stack_ptr_wb;
    wire [31:0] stack_ptr_out;
    wire [31:0] stack_ptr_top;
    wire stack_ptr_overflow;

    // Instruction ROM interface
    wire [31:0] instr_rom_data;

    // Instruction decode
    always @(posedge clk) begin
        if (reset) begin
            instr_a <= 0;
            instr_b <= 0;
            instr_c <= 0;
            instr_bx <= 0;
            instr_k <= 0;
            opcode_key <= 0;
        end else if (!reg_cache_stall && !microcode_micro_active) begin
            ir <= instr_rom_data;
            instr_a <= ir[31:24];
            instr_b <= ir[23:16];
            instr_c <= ir[15:8];
            instr_bx <= ir[23:7];
            instr_k <= ir[6];
            opcode_key <= ir[22:16];
        end
    end

    // Microcode ROM address computation
    assign microcode_rom_addr = microcode_micro_active ? microcode_branch_target : {3'h0, opcode_key[6:0]};

    // Instantiate register cache
    reg_cache reg_cache_inst (
        .clk(clk),
        .reset(reset),
        .wb(stack_ptr_wb),
        .operand_offset(instr_a),
        .read_req(microcode_enable && !reg_cache_stall),
        .read_valid(reg_cache_read_valid),
        .read_data(reg_cache_read_data),
        .write_req(bus_wr && bus_ack && bus_rdy),
        .write_data({bus_data_in, bus_data_in}),
        .write_bus_req(reg_cache_write_bus_req),
        .write_bus_addr(reg_cache_write_bus_addr),
        .write_bus_data(reg_cache_write_bus_data),
        .bus_resp_valid(bus_ack && bus_rdy),
        .bus_resp_data({bus_data_in, bus_data_in}),
        .cache_miss(reg_cache_cache_miss),
        .stall(reg_cache_stall),
        .invalidate(microcode_micro_done && microcode_stack_op[1]),
        .hit_count(),
        .miss_count()
    );

    // Instantiate microcode ROM
    microcode_rom microcode_rom_inst (
        .clk(clk),
        .address(microcode_rom_addr),
        .data(microcode_rom_data)
    );

    // Instantiate microcode sequencer
    microcode_seq microcode_seq_inst (
        .clk(clk),
        .reset(reset),
        .opcode_key(opcode_key),
        .instr_a(instr_a),
        .instr_b(instr_b),
        .instr_c(instr_c),
        .instr_bx(instr_bx),
        .instr_k(instr_k),
        .rom_address(microcode_rom_addr),
        .rom_data(microcode_rom_data),
        .alu_op(microcode_alu_op),
        .reg_a_write(microcode_reg_a_write),
        .reg_b_read(microcode_reg_b_read),
        .reg_c_read(microcode_reg_c_read),
        .mem_op(microcode_mem_op),
        .pc_op(microcode_pc_op),
        .micro_branch(microcode_micro_branch),
        .gc_step(microcode_gc_step),
        .stack_op(microcode_stack_op),
        .enable(microcode_enable),
        .immediate(microcode_immediate),
        .micro_active(microcode_micro_active),
        .micro_done(microcode_micro_done),
        .branch_target(microcode_branch_target)
    );

    // Instantiate stack pointer
    stack_ptr stack_ptr_inst (
        .clk(clk),
        .reset(reset),
        .wb(stack_ptr_wb),
        .stack_ptr_out(stack_ptr_out),
        .top(stack_ptr_top),
        .stack_push(bus_wr && bus_ack && bus_rdy),
        .stack_pop(0),
        .stack_push_count(8'h1),
        .wb_update(microcode_micro_active && microcode_stack_op != 2'h0),
        .wb_op(microcode_stack_op),
        .wb_value(microcode_immediate[15:0]),
        .stack_overflow(stack_ptr_overflow),
        .clear_top(microcode_micro_done)
    );

    // Instantiate instruction ROM
    instr_rom instr_rom_inst (
        .clk(clk),
        .address(pc),
        .data(instr_rom_data)
    );

    // Bus controller
    always @(posedge clk) begin
        if (reset) begin
            bus_state_idle <= 1;
            bus_state_req <= 0;
            bus_state_wait <= 0;
            bus_addr <= 0;
            bus_data_out <= 0;
            bus_req <= 0;
            bus_wr <= 0;
        end else if (halt_flag || error_flag) begin
            bus_state_idle <= 1;
            bus_state_req <= 0;
            bus_state_wait <= 0;
            bus_req <= 0;
        end else begin
            if (bus_state_idle) begin
                if (reg_cache_write_bus_req) begin
                    bus_addr <= reg_cache_write_bus_addr;
                    bus_data_out <= reg_cache_write_bus_data[31:0];
                    bus_wr <= 1;
                    bus_req <= 1;
                    bus_state_idle <= 0;
                    bus_state_req <= 1;
                end
            end else if (bus_state_req) begin
                if (bus_rdy) begin
                    bus_state_req <= 0;
                    bus_state_wait <= 1;
                end
            end else if (bus_state_wait) begin
                if (bus_ack && bus_rdy) begin
                    bus_state_wait <= 0;
                    bus_req <= 0;
                    bus_state_idle <= 1;
                end
            end
        end
    end

    // PC update
    always @(posedge clk) begin
        if (reset) begin
            pc <= 0;
        end else if (halt_flag || error_flag) begin
            pc <= pc;
        end else if (microcode_micro_active && microcode_pc_op == 3'h1) begin
            pc <= pc + 1;
        end else if (microcode_micro_active && microcode_pc_op == 3'h2) begin
            pc <= pc + {{15{microcode_immediate[16]}}, microcode_immediate[16:0]};
        end else if (microcode_micro_done && !microcode_micro_active) begin
            pc <= pc + 1;
        end
    end

    // Error and halt
    always @(posedge clk) begin
        if (reset) begin
            error_flag <= 0;
            halt_flag <= 0;
            error_code <= 0;
            gc_state_idle <= 1;
            alloc_counter <= 0;
            uart_tx_fifo_count <= 0;
        end else if (stack_ptr_overflow) begin
            error_flag <= 1;
            halt_flag <= 1;
            error_code <= 8'h01;
        end
    end

endmodule
