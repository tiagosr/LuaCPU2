module microcode_seq #(
    parameter ROM_DEPTH = 1024
)(
    input  wire clk,
    input  wire reset,

    input  wire [6:0] opcode_key,

    input  wire [7:0] instr_a,
    input  wire [7:0] instr_b,
    input  wire [7:0] instr_c,
    input  wire [16:0] instr_bx,
    input  wire instr_k,

    input  wire [9:0] rom_address,
    input  wire [63:0] rom_data,

    output reg [4:0] alu_op,
    output reg [3:0] reg_a_write,
    output reg [3:0] reg_b_read,
    output reg [3:0] reg_c_read,
    output reg [2:0] mem_op,
    output reg [2:0] pc_op,
    output reg [1:0] micro_branch,
    output reg [1:0] gc_step,
    output reg [1:0] stack_op,
    output reg enable,
    output reg [33:0] immediate,

    output reg micro_active,
    output reg micro_done,

    output reg [9:0] branch_target
);

    wire [4:0] rom_alu_op;
    wire [3:0] rom_reg_a_write;
    wire [3:0] rom_reg_b_read;
    wire [3:0] rom_reg_c_read;
    wire [2:0] rom_mem_op;
    wire [2:0] rom_pc_op;
    wire [1:0] rom_micro_branch;
    wire [1:0] rom_gc_step;
    wire [1:0] rom_stack_op;
    wire rom_enable;
    wire [33:0] rom_immediate;

    assign rom_alu_op = rom_data[63:59];
    assign rom_reg_a_write = rom_data[58:55];
    assign rom_reg_b_read = rom_data[54:51];
    assign rom_reg_c_read = rom_data[50:47];
    assign rom_mem_op = rom_data[46:44];
    assign rom_pc_op = rom_data[43:41];
    assign rom_micro_branch = rom_data[40:39];
    assign rom_gc_step = rom_data[38:37];
    assign rom_stack_op = rom_data[36:35];
    assign rom_enable = rom_data[34];
    assign rom_immediate = rom_data[33:0];

    reg [33:0] immediate_source;

    always_comb begin
        case (opcode_key)
            7'h01: immediate_source = {17'h00000, instr_bx};
            7'h02: immediate_source = {17'h00000, instr_bx};
            7'h21: immediate_source = {26'h0000000000, instr_c};
            7'h20: immediate_source = {26'h0000000000, instr_c};
            7'h56: immediate_source = {17'h00000, instr_bx};
            7'h73: immediate_source = {17'h00000, instr_bx};
            7'h74: immediate_source = {17'h00000, instr_bx};
            7'h77: immediate_source = {17'h00000, instr_bx};
            7'h75: immediate_source = {17'h00000, instr_bx};
            default: immediate_source = 34'h0;
        endcase
    end

    reg [9:0] next_internal_addr;
    reg [4:0] next_alu_op;
    reg [3:0] next_reg_a_write;
    reg [3:0] next_reg_b_read;
    reg [3:0] next_reg_c_read;
    reg [2:0] next_mem_op;
    reg [2:0] next_pc_op;
    reg [1:0] next_micro_branch;
    reg [1:0] next_gc_step;
    reg [1:0] next_stack_op;
    reg next_enable;
    reg [33:0] next_immediate;
    reg next_micro_active;
    reg next_micro_done;
    reg [9:0] next_branch_target;

    always_comb begin
        if (reset) begin
            next_internal_addr = 10'h0;
            next_alu_op = 5'h0;
            next_reg_a_write = 4'h0;
            next_reg_b_read = 4'h0;
            next_reg_c_read = 4'h0;
            next_mem_op = 3'h0;
            next_pc_op = 3'h0;
            next_micro_branch = 2'h1;
            next_gc_step = 2'h0;
            next_stack_op = 2'h0;
            next_enable = 1'b0;
            next_immediate = 34'h0;
            next_micro_active = 1'b0;
            next_micro_done = 1'b1;
            next_branch_target = 10'h0;
        end else begin
            case (micro_active)
                1'b0: begin
                    next_internal_addr = {3'h0, opcode_key[6:0]};
                    next_alu_op = rom_alu_op;
                    next_reg_a_write = rom_reg_a_write;
                    next_reg_b_read = rom_reg_b_read;
                    next_reg_c_read = rom_reg_c_read;
                    next_mem_op = rom_mem_op;
                    next_pc_op = rom_pc_op;
                    next_micro_branch = rom_micro_branch;
                    next_gc_step = rom_gc_step;
                    next_stack_op = rom_stack_op;
                    next_enable = rom_enable;
                    next_immediate = immediate_source;
                    next_micro_active = 1'b1;
                    next_micro_done = 1'b0;
                    next_branch_target = 10'h0;

                    if (rom_micro_branch == 2'h1) begin
                        next_micro_active = 1'b0;
                        next_micro_done = 1'b1;
                    end
                end
                1'b1: begin
                    next_internal_addr = rom_address + 1;
                    next_alu_op = rom_alu_op;
                    next_reg_a_write = rom_reg_a_write;
                    next_reg_b_read = rom_reg_b_read;
                    next_reg_c_read = rom_reg_c_read;
                    next_mem_op = rom_mem_op;
                    next_pc_op = rom_pc_op;
                    next_micro_branch = rom_micro_branch;
                    next_gc_step = rom_gc_step;
                    next_stack_op = rom_stack_op;
                    next_enable = rom_enable;
                    next_immediate = immediate_source;
                    next_micro_active = micro_active;
                    next_micro_done = micro_done;
                    next_branch_target = 10'h0;

                    case (rom_micro_branch)
                        2'h0: begin
                            next_internal_addr = rom_address + 1;
                            next_micro_active = micro_active;
                            next_micro_done = micro_done;
                        end
                        2'h1: begin
                            next_internal_addr = rom_address;
                            next_micro_active = 1'b0;
                            next_micro_done = 1'b1;
                        end
                        2'h2: begin
                            next_internal_addr = rom_address + 1;
                            next_micro_active = micro_active;
                            next_micro_done = micro_done;
                            next_branch_target = immediate_source[9:0];
                        end
                        2'h3: begin
                            next_internal_addr = rom_address;
                            next_micro_active = 1'b0;
                            next_micro_done = 1'b1;
                        end
                        default: begin
                            next_internal_addr = rom_address + 1;
                            next_micro_active = micro_active;
                            next_micro_done = micro_done;
                        end
                    endcase
                end
                default: begin
                    next_internal_addr = 10'h0;
                    next_alu_op = 5'h0;
                    next_reg_a_write = 4'h0;
                    next_reg_b_read = 4'h0;
                    next_reg_c_read = 4'h0;
                    next_mem_op = 3'h0;
                    next_pc_op = 3'h0;
                    next_micro_branch = 2'h1;
                    next_gc_step = 2'h0;
                    next_stack_op = 2'h0;
                    next_enable = 1'b0;
                    next_immediate = 34'h0;
                    next_micro_active = 1'b0;
                    next_micro_done = 1'b1;
                    next_branch_target = 10'h0;
                end
            endcase
        end
    end

    reg [9:0] sequencer_addr;

    always @(posedge clk) begin
        if (reset) begin
            sequencer_addr <= 10'h0;
            alu_op <= 5'h0;
            reg_a_write <= 4'h0;
            reg_b_read <= 4'h0;
            reg_c_read <= 4'h0;
            mem_op <= 3'h0;
            pc_op <= 3'h0;
            micro_branch <= 2'h1;
            gc_step <= 2'h0;
            stack_op <= 2'h0;
            enable <= 1'b0;
            immediate <= 34'h0;
            micro_active <= 1'b0;
            micro_done <= 1'b1;
            branch_target <= 10'h0;
        end else begin
            sequencer_addr <= next_internal_addr;
            alu_op <= next_alu_op;
            reg_a_write <= next_reg_a_write;
            reg_b_read <= next_reg_b_read;
            reg_c_read <= next_reg_c_read;
            mem_op <= next_mem_op;
            pc_op <= next_pc_op;
            micro_branch <= next_micro_branch;
            gc_step <= next_gc_step;
            stack_op <= next_stack_op;
            enable <= next_enable;
            immediate <= next_immediate;
            micro_active <= next_micro_active;
            micro_done <= next_micro_done;
            branch_target <= next_branch_target;
        end
    end

endmodule
