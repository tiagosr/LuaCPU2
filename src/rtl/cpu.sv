/* verilator lint_off WIDTHEXPAND */
/* verilator lint_off WIDTHTRUNC */
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

    // Instruction register and operand fields
    reg [31:0] ir;
    reg [7:0] instr_a;
    reg [7:0] instr_b;
    reg [7:0] instr_c;
    reg [16:0] instr_bx;
    reg instr_k;
    reg [6:0] opcode_key;
    reg [24:0] instr_ax;
    reg instr_decoded;

    // Bus state machine
    reg bus_idle;
    reg bus_request;
    reg bus_wait;

    // K-table read buffer
    reg [31:0] ktable_data;
    reg ktable_valid;
    reg ktable_waiting;

    // Microcode ROM address
    wire [9:0] microcode_rom_addr;

    // Register cache interface
    wire [63:0] reg_cache_read_data;
    wire reg_cache_read_valid;
    wire reg_cache_stall;

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
    wire microcode_active;
    wire microcode_done;
    wire [9:0] microcode_branch_target;
    wire [9:0] microcode_sequencer_addr;

    // Stack pointer interface
    wire [31:0] stack_ptr_wb;

    // Instruction ROM interface
    wire [31:0] instr_rom_data;

    // ALU interface
    wire [63:0] alu_result;
    wire alu_result_valid;
    wire alu_div_zero_flag;
    wire alu_type_error_flag;

    // Value converter interface
    wire [63:0] value_conv_load_value;
    wire value_conv_load_value_valid;

    // Write commit
    reg write_commit;
    reg [63:0] write_data;
    reg [7:0] write_offset;

    localparam KTABLE_BASE = 256;

    // Register cache read offset
    wire [7:0] reg_cache_read_offset;
    assign reg_cache_read_offset = (microcode_active && microcode_enable && microcode_reg_b_read != 4'h0) ? instr_b : instr_a;

    // Instantiate instruction ROM
    instr_rom instr_rom_inst (
        .clk(clk),
        .address(pc),
        .data(instr_rom_data)
    );

    // Instantiate register cache
    reg_cache reg_cache_inst (
        .clk(clk),
        .reset(reset),
        .wb(stack_ptr_wb),
        .operand_offset(reg_cache_read_offset),
        .write_offset(instr_a),
        .read_req(microcode_active && microcode_enable && microcode_reg_b_read != 4'h0),
        .read_valid(reg_cache_read_valid),
        .read_data(reg_cache_read_data),
        .write_req(write_commit && bus_idle && instr_decoded),
        .write_data(write_data),
        .bus_resp_valid(bus_ack && bus_rdy && bus_wr == 0),
        .bus_resp_data({bus_data_in, bus_data_in}),
        .cache_miss(),
        .stall(reg_cache_stall),
        .invalidate(microcode_done && microcode_stack_op[1]),
        .hit_count(),
        .miss_count()
    );

    // Instantiate ALU
    alu alu_inst (
        .clk(clk),
        .reset(reset),
        .alu_op(microcode_alu_op),
        .operand_a(reg_cache_read_data),
        .operand_b(reg_cache_read_data),
        .operand_c({ktable_data, ktable_data}),
        .immediate(microcode_immediate),
        .result(alu_result),
        .result_valid(alu_result_valid),
        .zero_flag(),
        .div_zero_flag(alu_div_zero_flag),
        .type_error_flag(alu_type_error_flag)
    );

    // Instantiate value converter
    value_conv value_conv_inst (
        .clk(clk),
        .reset(reset),
        .alu_op(microcode_alu_op),
        .immediate(microcode_immediate),
        .ktable_data({ktable_data, ktable_data}),
        .load_value(value_conv_load_value),
        .load_value_valid(value_conv_load_value_valid)
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
        .instr_ax(instr_ax),
        .rom_address(microcode_sequencer_addr),
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
        .micro_active(microcode_active),
        .micro_done(microcode_done),
        .branch_target(microcode_branch_target),
        .sequencer_addr_out(microcode_sequencer_addr),
        .micro_stall_in(reg_cache_stall || ktable_waiting)
    );

    // Instantiate stack pointer
    stack_ptr stack_ptr_inst (
        .clk(clk),
        .reset(reset),
        .wb(stack_ptr_wb),
        .stack_ptr_out(),
        .top(),
        .stack_push(write_commit && bus_wr),
        .stack_pop(0),
        .stack_push_count(8'h1),
        .wb_update(microcode_active && microcode_stack_op != 2'h0),
        .wb_op(microcode_stack_op),
        .wb_value(microcode_immediate[15:0]),
        .stack_overflow(),
        .clear_top(microcode_done)
    );

    // Microcode ROM address
    assign microcode_rom_addr = microcode_sequencer_addr;

    // PC update
    always @(posedge clk) begin
        if (reset) begin
            pc <= 0;
            instr_decoded <= 0;
        end else if (halt_flag || error_flag) begin
            pc <= pc;
        end else if (instr_decoded && !reg_cache_stall && !microcode_active && !ktable_waiting) begin
            pc <= pc + 1;
            instr_decoded <= 0;
        end else if (microcode_active && microcode_pc_op == 3'h1) begin
            pc <= pc + 1;
            instr_decoded <= 0;
        end else if (microcode_active && microcode_pc_op == 3'h2) begin
            pc <= pc + {{15{microcode_immediate[16]}}, microcode_immediate[16:0]};
            instr_decoded <= 0;
        end
    end

    // Instruction decode
    always @(posedge clk) begin
        if (reset) begin
            ir <= 0;
            instr_a <= 0;
            instr_b <= 0;
            instr_c <= 0;
            instr_bx <= 0;
            instr_k <= 0;
            opcode_key <= 0;
            instr_ax <= 0;
            instr_decoded <= 0;
        end else if (halt_flag || error_flag) begin
            instr_decoded <= 0;
        end else if (!reg_cache_stall && !microcode_active && !ktable_waiting && !instr_decoded) begin
            ir <= instr_rom_data;
            instr_a <= ir[31:24];
            instr_b <= ir[23:16];
            instr_c <= ir[15:8];
            instr_bx <= {ir[23], ir[15:0]};
            instr_k <= ir[6];
            opcode_key <= ir[22:16];
            instr_decoded <= 1;
        end else if (!reg_cache_stall && microcode_active && !ktable_waiting && opcode_key == 7'h04) begin
            instr_ax <= instr_rom_data[24:0];
        end
    end

    // K-table read path
    always @(posedge clk) begin
        if (reset) begin
            ktable_data <= 0;
            ktable_valid <= 0;
            ktable_waiting <= 0;
        end else if (halt_flag || error_flag) begin
            ktable_waiting <= 0;
        end else begin
            if (ktable_waiting) begin
                if (bus_ack && bus_rdy && bus_wr == 0) begin
                    ktable_data <= bus_data_in;
                    ktable_valid <= 1;
                    ktable_waiting <= 0;
                end
            end else if (microcode_active && microcode_enable && microcode_mem_op == 3'h1) begin
                ktable_waiting <= 1;
                ktable_valid <= 0;
            end
        end
    end

    // Write commit data selection
    always @(posedge clk) begin
        if (reset) begin
            write_data <= 0;
            write_offset <= 0;
            write_commit <= 0;
        end else if (halt_flag || error_flag) begin
            write_commit <= 0;
        end else if (microcode_active && microcode_enable && microcode_reg_a_write == 4'h0 && !bus_request) begin
            if (microcode_mem_op == 3'h1 && ktable_valid) begin
                write_data <= {ktable_data, ktable_data};
                write_offset <= instr_a;
                write_commit <= 1;
            end else if (microcode_alu_op != 5'h0 && alu_result_valid) begin
                write_data <= alu_result;
                write_offset <= instr_a;
                write_commit <= 1;
            end else if (reg_cache_read_valid && microcode_reg_b_read != 4'h0) begin
                write_data <= reg_cache_read_data;
                write_offset <= instr_a;
                write_commit <= 1;
            end else if (value_conv_load_value_valid) begin
                write_data <= value_conv_load_value;
                write_offset <= instr_a;
                write_commit <= 1;
            end else begin
                write_commit <= 0;
            end
        end else begin
            write_commit <= 0;
        end
    end

    // Bus controller
    always @(posedge clk) begin
        if (reset) begin
            bus_idle <= 1;
            bus_request <= 0;
            bus_wait <= 0;
            bus_addr <= 0;
            bus_data_out <= 0;
            bus_req <= 0;
            bus_wr <= 0;
        end else if (halt_flag || error_flag) begin
            bus_idle <= 1;
            bus_request <= 0;
            bus_wait <= 0;
            bus_req <= 0;
        end else begin
            if (bus_idle) begin
                if (ktable_waiting) begin
                    bus_addr <= KTABLE_BASE + microcode_immediate[15:0];
                    bus_wr <= 0;
                    bus_req <= 1;
                    bus_idle <= 0;
                    bus_request <= 1;
                end else if (write_commit) begin
                    bus_addr <= write_offset + stack_ptr_wb;
                    bus_data_out <= write_data[31:0];
                    bus_wr <= 1;
                    bus_req <= 1;
                    bus_idle <= 0;
                    bus_request <= 1;
                end
            end else if (bus_request) begin
                if (bus_rdy) begin
                    bus_request <= 0;
                    bus_wait <= 1;
                end
            end else if (bus_wait) begin
                if (bus_ack) begin
                    bus_wait <= 0;
                    bus_req <= 0;
                    bus_idle <= 1;
                end
            end
        end
    end

    // Error and halt
    always @(posedge clk) begin
        if (reset) begin
            error_flag <= 0;
            halt_flag <= 0;
            error_code <= 0;
        end else begin
            if (alu_div_zero_flag) begin
                error_flag <= 1;
                halt_flag <= 1;
                error_code <= 8'h02;
            end else if (alu_type_error_flag) begin
                error_flag <= 1;
                halt_flag <= 1;
                error_code <= 8'h03;
            end
        end
    end

/* verilator lint_on WIDTHTRUNC */
/* verilator lint_on WIDTHEXPAND */
endmodule
