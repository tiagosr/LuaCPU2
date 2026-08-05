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

    reg [31:0] pc;
    reg [31:0] ir;
    reg [7:0] instr_a;
    reg [7:0] instr_b;
    reg [7:0] instr_c;
    reg [16:0] instr_bx;
    reg instr_k;
    reg [6:0] opcode_key;
    reg [1:0] opcode_step;
    reg [24:0] instr_ax;
    reg instr_decoded;

    reg bus_idle;
    reg bus_request;
    reg bus_wait;
    reg bus_writeback;

    reg [63:0] b_operand_latch;
    reg [63:0] b_operand_pipe;

    reg [63:0] value_conv_latched_value;
    reg value_conv_latched_valid;

    reg writeback_ready;

    reg [63:0] ktable_data;
    reg ktable_valid;
    reg ktable_waiting;

    reg [63:0] table_temp;

    wire [10:0] microcode_rom_addr;

    wire [63:0] reg_cache_read_data;
    wire reg_cache_read_valid;
    wire reg_cache_stall;
    wire [63:0] reg_cache_read_c_data;
    wire reg_cache_read_c_valid;
    wire reg_cache_stall_c;
    wire reg_cache_cache_miss;

    wire [63:0] microcode_rom_data;

    wire [4:0] microcode_alu_op;
    wire [1:0] microcode_alu_optype;
    wire [3:0] microcode_dest_sel;
    wire [4:0] microcode_operand_a_sel;
    wire [4:0] microcode_operand_b_sel;
    wire [3:0] microcode_source;
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
    wire microcode_writeback_ready;
    wire [9:0] microcode_branch_target;
    wire [10:0] microcode_sequencer_addr;

    wire [31:0] stack_ptr_wb;

    wire [31:0] instr_rom_data;

    var  [63:0] alu_operand_b;
    wire [63:0] alu_result;
    wire alu_result_valid;
    wire alu_div_zero_flag;
    wire alu_type_error_flag;

    wire [63:0] value_conv_load_value;
    wire value_conv_load_value_valid;
    wire value_conv_load_value_valid_comb;

    localparam KTABLE_BASE = 256;

    wire reg_cache_read_b_req;
    wire reg_cache_read_c_req;
    wire [7:0] reg_cache_read_offset;
    wire [7:0] reg_cache_read_c_offset;

    assign reg_cache_read_b_req = latched_enable && latched_operand_a_sel != 4'h0 && latched_operand_a_sel != 4'h3;
    assign reg_cache_read_c_req = latched_enable && latched_operand_b_sel != 4'h0 && latched_operand_b_sel != 4'h3;
    assign reg_cache_read_offset = reg_cache_read_b_req ? instr_b : instr_a;
    assign reg_cache_read_c_offset = reg_cache_read_c_req ? instr_c : instr_a;
    assign microcode_enable = 1;

    always @(*) begin
        alu_operand_b = reg_cache_read_data;
        if (microcode_active) begin
            /* verilator lint_off CASEINCOMPLETE */
            case (microcode_operand_b_sel)
                SOURCE_ZERO: alu_operand_b = 64'h0;
                SOURCE_K_B, SOURCE_K_C, SOURCE_K_EXTRA: if (ktable_valid) alu_operand_b = ktable_data;
                SOURCE_REG_A, SOURCE_REG_B, SOURCE_REG_C: if (reg_cache_read_c_valid) alu_operand_b = reg_cache_read_c_data;
                SOURCE_SC: alu_operand_b = nan_box_integer({{24{instr_c[7]}},instr_c});
                SOURCE_SAX: alu_operand_b = nan_box_integer({{8{instr_ax[23]}},instr_ax});
                SOURCE_TEMPTABLE: alu_operand_b = table_temp;
            endcase
            /* verilator lint_on CASEINCOMPLETE */
        end
    end

    instr_rom instr_rom_inst (
        .clk(clk),
        .address(pc),
        .data(instr_rom_data)
    );

    reg_cache reg_cache_inst (
        .clk(clk),
        .reset(reset),
        .wb(stack_ptr_wb),
        .operand_offset(reg_cache_read_offset),
        .operand_c_offset(reg_cache_read_c_offset),
        .write_offset(instr_a),
        .read_req(reg_cache_read_b_req && !reg_cache_stall),
        .read_valid(reg_cache_read_valid),
        .read_data(reg_cache_read_data),
        .read_c_req(reg_cache_read_c_req && !reg_cache_stall_c && !reg_cache_stall),
        .read_c_valid(reg_cache_read_c_valid),
        .read_c_data(reg_cache_read_c_data),
        .write_req(0),
        .write_data(alu_result),
        .bus_resp_valid(bus_ack && bus_rdy && bus_wr == 0),
        .bus_resp_data({bus_data_in, bus_data_in}),
        .cache_miss(reg_cache_cache_miss),
        .stall(reg_cache_stall),
        .stall_c(reg_cache_stall_c),
        .invalidate(microcode_done && microcode_stack_op[1]),
        .hit_count(),
        .miss_count()
    );

    alu alu_inst (
        .clk(clk),
        .reset(reset),
        .alu_op(microcode_alu_op),
        .alu_optype(microcode_alu_optype),
        .operand_a(b_operand_pipe),
        .operand_b(alu_operand_b),
        .test_compare_k(instr_k),
        .immediate(microcode_immediate),
        .result(alu_result),
        .result_valid(alu_result_valid),
        .zero_flag(),
        .div_zero_flag(alu_div_zero_flag),
        .type_error_flag(alu_type_error_flag)
    );

    /* verilator lint_off PINMISSING */
    value_conv value_conv_inst (
        .clk(clk),
        .reset(reset),
        .alu_op(microcode_alu_op),
        .immediate(microcode_immediate),
        .ktable_data({ktable_data, ktable_data}),
        .load_value(value_conv_load_value),
        .load_value_valid(value_conv_load_value_valid),
        .load_value_valid_comb(value_conv_load_value_valid_comb)
    );
    /* verilator lint_on PINMISSING */

    microcode_rom microcode_rom_inst (
        .clk(clk),
        .opcode(opcode_key),
        .step(opcode_step),
        .next_microop(),
        .alu_op(microcode_alu_op),
        .alu_optype(microcode_alu_optype),
        .dest(microcode_dest_sel),
        .operand_a_sel(microcode_operand_a_sel),
        .operand_b_sel(microcode_operand_b_sel),
        .pc_op(microcode_pc_op),
        .stack_op()
    );

    stack_ptr stack_ptr_inst (
        .clk(clk),
        .reset(reset),
        .wb(stack_ptr_wb),
        .stack_ptr_out(),
        .top(),
        .stack_push(0),
        .stack_pop(0),
        .stack_push_count(8'h1),
        .wb_update(microcode_active && microcode_stack_op != 2'h0),
        .wb_op(microcode_stack_op),
        .wb_value(microcode_immediate[15:0]),
        .stack_overflow(),
        .clear_top(microcode_done)
    );

    assign microcode_rom_addr = microcode_sequencer_addr;

    reg latched_enable;
    reg [33:0] latched_immediate;
    reg [7:0] latched_instr_a;
    reg [3:0] latched_operand_a_sel;
    reg [3:0] latched_operand_b_sel;
    reg [63:0] latched_b_operand_pipe;
    reg latched_reg_cache_read_valid;
    reg [63:0] latched_value_conv_load_value;
    reg [1:0] latched_value_conv_load_value_valid;

    always @(posedge clk) begin
        if (reset) begin
            writeback_ready <= 0;
        end else if (halt_flag || error_flag) begin
            writeback_ready <= 0;
        end else begin
            if (microcode_writeback_ready && bus_idle && !bus_writeback && !bus_request && !bus_wait && !writeback_ready) begin
                writeback_ready <= 1;
            end else if (bus_writeback || bus_request || bus_wait) begin
                writeback_ready <= 0;
            end
        end
    end

    always @(posedge clk) begin
        if (reset) begin
            latched_enable <= 1'b0;
            latched_immediate <= 34'h0;
            latched_instr_a <= 0;
            latched_operand_a_sel <= 4'h0;
            latched_operand_b_sel <= 4'h0;
            latched_b_operand_pipe <= 0;
            latched_reg_cache_read_valid <= 0;
            latched_value_conv_load_value <= 0;
            latched_value_conv_load_value_valid <= 0;
            table_temp <= 0;
            value_conv_latched_value <= 0;
            value_conv_latched_valid <= 0;
        end else if (halt_flag || error_flag) begin
            latched_enable <= 1'b0;
            latched_immediate <= 34'h0;
            latched_instr_a <= 0;
            latched_operand_a_sel <= 4'h0;
            latched_operand_b_sel <= 4'h0;
            latched_b_operand_pipe <= 0;
            latched_reg_cache_read_valid <= 0;
            latched_value_conv_load_value <= 0;
            table_temp <= 0;
        end else if (value_conv_load_value_valid) begin
            value_conv_latched_value <= value_conv_load_value;
            value_conv_latched_valid <= 1;
        end else if (bus_writeback) begin
            value_conv_latched_valid <= 0;
        end else if (microcode_writeback_ready && bus_idle && !bus_writeback && !bus_request && !bus_wait) begin
            latched_enable <= microcode_enable;
            latched_immediate <= microcode_immediate;
            latched_instr_a <= instr_a;
            latched_operand_a_sel <= microcode_operand_a_sel;
            latched_operand_b_sel <= microcode_operand_b_sel;
            latched_b_operand_pipe <= b_operand_pipe;
            latched_reg_cache_read_valid <= reg_cache_read_valid;
            latched_value_conv_load_value <= value_conv_load_value;
            latched_value_conv_load_value_valid <= value_conv_load_value_valid;
        end
    end

    always @(posedge clk) begin
        if (reset) begin
            pc <= 0;
            instr_decoded <= 0;
        end else if (halt_flag || error_flag) begin
            pc <= pc;
            instr_decoded <= 0;
        end else if (microcode_active && microcode_pc_op == PC_SKIP) begin
            pc <= pc + 1;
            instr_decoded <= 0;
        end else if (microcode_active && microcode_pc_op == PC_SET) begin
            if (microcode_dest_sel == DEST_PC && alu_result_valid) begin
                pc <= alu_result[31:0];
            end else begin
                pc <= pc + {{15{microcode_immediate[16]}}, microcode_immediate[16:0]};
            end
            instr_decoded <= 0;
        end else if (writeback_ready && !reg_cache_stall && !ktable_waiting && !microcode_active && microcode_pc_op == PC_ADVANCE) begin
            instr_decoded <= 0;
            pc <= pc + 1;
        end
    end

    always @(posedge clk) begin
        if (reset) begin
            ir <= 0;
            instr_decoded <= 0;
        end else if (halt_flag || error_flag) begin
            instr_decoded <= 0;
        end else if (!reg_cache_stall && !microcode_active && !ktable_waiting && !instr_decoded) begin
            ir <= instr_rom_data;
            instr_decoded <= 1;
        end
    end

    assign {instr_c, instr_b, instr_k, instr_a, opcode_key} = ir;
    assign instr_bx = ir[31:16];
    assign instr_ax = ir[31:7];

    always @(posedge clk) begin
        if (reset) begin
            b_operand_latch <= 0;
            b_operand_pipe <= 0;
        end else if (halt_flag || error_flag) begin
            b_operand_latch <= 0;
            b_operand_pipe <= 0;
        end else if (reg_cache_read_valid && microcode_operand_a_sel != SOURCE_ZERO) begin
            b_operand_latch <= reg_cache_read_data;
        end else if (ktable_valid && microcode_mem_op == 3'h1) begin
            b_operand_latch <= {ktable_data, ktable_data};
        end else begin
            b_operand_latch <= b_operand_latch;
        end
        b_operand_pipe <= b_operand_latch;
    end

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

    always @(posedge clk) begin
        if (reset) begin
            bus_idle <= 1;
            bus_request <= 0;
            bus_wait <= 0;
            bus_writeback <= 0;
            bus_addr <= 0;
            bus_data_out <= 0;
            bus_req <= 0;
            bus_wr <= 0;
            bus_data_out <= 0;
        end else if (halt_flag || error_flag) begin
            bus_idle <= 1;
            bus_request <= 0;
            bus_wait <= 0;
            bus_writeback <= 0;
            bus_req <= 0;
        end else begin
            if (bus_idle) begin
                bus_wr <= 0;
                bus_data_out <= 0;
                if (ktable_waiting) begin
                    bus_addr <= KTABLE_BASE + latched_immediate[15:0];
                    bus_wr <= 0;
                    bus_req <= 1;
                    bus_idle <= 0;
                    bus_request <= 1;
                end else if (reg_cache_cache_miss && microcode_mem_op != 3'h1 && !writeback_ready) begin
                    bus_addr <= stack_ptr_wb + reg_cache_read_offset;
                    bus_wr <= 0;
                    bus_req <= 1;
                    bus_idle <= 0;
                    bus_request <= 1;
                end else if (writeback_ready && microcode_enable && !reg_cache_stall && !ktable_waiting) begin
                    if (microcode_alu_op != 5'h0 && alu_result_valid) begin
                        bus_addr <= instr_a + stack_ptr_wb;
                        bus_data_out <= alu_result[31:0];
                        bus_wr <= 1;
                        bus_req <= 1;
                        bus_idle <= 0;
                        bus_writeback <= 1;
                    end else if (ktable_valid && microcode_mem_op == 3'h1) begin
                        bus_addr <= instr_a + stack_ptr_wb;
                        bus_data_out <= ktable_data[31:0];
                        bus_wr <= 1;
                        bus_req <= 1;
                        bus_idle <= 0;
                        bus_writeback <= 1;
                    end else if (latched_reg_cache_read_valid && microcode_alu_op == 5'h0 && latched_operand_a_sel != 4'h0) begin
                        bus_addr <= latched_instr_a + stack_ptr_wb;
                        bus_data_out <= latched_b_operand_pipe[31:0];
                        bus_wr <= 1;
                        bus_req <= 1;
                        bus_idle <= 0;
                        bus_writeback <= 1;
                    end else if (value_conv_latched_valid && microcode_alu_op == 5'h0) begin
                        bus_addr <= latched_instr_a + stack_ptr_wb;
                        bus_data_out <= value_conv_latched_value[31:0];
                        bus_wr <= 1;
                        bus_req <= 1;
                        bus_idle <= 0;
                        bus_writeback <= 1;
                    end
                end
            end else if (bus_request) begin
                if (bus_rdy) begin
                    bus_request <= 0;
                    bus_wait <= 1;
                end
            end else if (bus_writeback) begin
                if (bus_rdy) begin
                    bus_writeback <= 0;
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
