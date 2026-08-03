module microcode_rom #(
    parameter ROM_DEPTH = 1024,
    parameter ROM_WIDTH = 64
)(
    input  wire clk,
    input  wire [9:0] address,
    output wire [ROM_WIDTH-1:0] data
);

    localparam [63:0] OP_MOVE = {
        5'h0,   // alu_op = pass
        4'h0,   // reg_a_write = window index A
        4'h1,   // reg_b_read = window index B
        4'h0,   // reg_c_read = unused
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h0,   // micro_branch = continue
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_MOVE_DONE = {
        5'h0,   // alu_op = pass
        4'h0,   // reg_a_write = window index A
        4'h0,   // reg_b_read = unused
        4'h0,   // reg_c_read = unused
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h1,   // micro_branch = terminate
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_LOADI = {
        5'h0,   // alu_op = pass
        4'h0,   // reg_a_write = window index A
        4'h0,   // reg_b_read = unused
        4'h0,   // reg_c_read = unused
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h1,   // micro_branch = terminate
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = placeholder (filled by sequencer)
    };

    localparam [63:0] OP_LOADK = {
        5'h0,   // alu_op = pass
        4'h0,   // reg_a_write = window index A
        4'h0,   // reg_b_read = unused
        4'h0,   // reg_c_read = unused
        3'h1,   // mem_op = read ktable
        3'h0,   // pc_op = no change
        2'h0,   // micro_branch = continue (needs bus response)
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = placeholder
    };

    localparam [63:0] OP_LOADK_DONE = {
        5'h0,   // alu_op = pass
        4'h0,   // reg_a_write = window index A
        4'h0,   // reg_b_read = unused
        4'h0,   // reg_c_read = unused
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h1,   // micro_branch = terminate
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_LOADTRUE = {
        5'h0,   // alu_op = pass
        4'h0,   // reg_a_write = window index A
        4'h0,   // reg_b_read = unused
        4'h0,   // reg_c_read = unused
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h1,   // micro_branch = terminate
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = placeholder
    };

    localparam [63:0] OP_LOADFALSE = {
        5'h0,   // alu_op = pass
        4'h0,   // reg_a_write = window index A
        4'h0,   // reg_b_read = unused
        4'h0,   // reg_c_read = unused
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h1,   // micro_branch = terminate
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = placeholder
    };

    localparam [63:0] OP_LOADF = {
        5'h0,   // alu_op = pass
        4'h0,   // reg_a_write = window index A
        4'h0,   // reg_b_read = unused
        4'h0,   // reg_c_read = unused
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h1,   // micro_branch = terminate
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = placeholder
    };

    localparam [63:0] OP_LOADNIL = {
        5'h4,   // alu_op = load nil
        4'h0,   // reg_a_write = window index A
        4'h0,   // reg_b_read = unused
        4'h0,   // reg_c_read = unused
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h1,   // micro_branch = terminate
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_LOADNIL_STEP = {
        5'h4,   // alu_op = load nil
        4'h0,   // reg_a_write = window index A
        4'h0,   // reg_b_read = unused
        4'h0,   // reg_c_read = unused
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h0,   // micro_branch = continue
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_LOADNIL_DONE = {
        5'h0,   // alu_op = pass
        4'h0,   // reg_a_write = window index A
        4'h0,   // reg_b_read = unused
        4'h0,   // reg_c_read = unused
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h1,   // micro_branch = terminate
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_LFALSESKIP = {
        5'h0,   // alu_op = pass
        4'h0,   // reg_a_write = window index A
        4'h0,   // reg_b_read = unused
        4'h0,   // reg_c_read = unused
        3'h0,   // mem_op = no access
        3'h1,   // pc_op = increment
        2'h1,   // micro_branch = terminate
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_ADD = {
        5'h1,   // alu_op = add
        4'h0,   // reg_a_write = window index A
        4'h1,   // reg_b_read = window index B
        4'h2,   // reg_c_read = window index C
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h1,   // micro_branch = terminate
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_SUB = {
        5'h2,   // alu_op = sub
        4'h0,   // reg_a_write = window index A
        4'h1,   // reg_b_read = window index B
        4'h2,   // reg_c_read = window index C
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h1,   // micro_branch = terminate
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_MUL = {
        5'h3,   // alu_op = mul
        4'h0,   // reg_a_write = window index A
        4'h1,   // reg_b_read = window index B
        4'h2,   // reg_c_read = window index C
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h1,   // micro_branch = terminate
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_DIV = {
        5'h4,   // alu_op = div
        4'h0,   // reg_a_write = window index A
        4'h1,   // reg_b_read = window index B
        4'h2,   // reg_c_read = window index C
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h1,   // micro_branch = terminate
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_UNM = {
        5'h5,   // alu_op = neg
        4'h0,   // reg_a_write = window index A
        4'h1,   // reg_b_read = window index B
        4'h0,   // reg_c_read = unused
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h1,   // micro_branch = terminate
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_NOT = {
        5'h6,   // alu_op = not
        4'h0,   // reg_a_write = window index A
        4'h1,   // reg_b_read = window index B
        4'h0,   // reg_c_read = unused
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h1,   // micro_branch = terminate
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_BNOT = {
        5'h7,   // alu_op = bnot
        4'h0,   // reg_a_write = window index A
        4'h1,   // reg_b_read = window index B
        4'h0,   // reg_c_read = unused
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h1,   // micro_branch = terminate
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_BAND = {
        5'h8,   // alu_op = and
        4'h0,   // reg_a_write = window index A
        4'h1,   // reg_b_read = window index B
        4'h2,   // reg_c_read = window index C
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h1,   // micro_branch = terminate
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_BOR = {
        5'h9,   // alu_op = or
        4'h0,   // reg_a_write = window index A
        4'h1,   // reg_b_read = window index B
        4'h2,   // reg_c_read = window index C
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h1,   // micro_branch = terminate
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_BXOR = {
        5'hA,   // alu_op = xor
        4'h0,   // reg_a_write = window index A
        4'h1,   // reg_b_read = window index B
        4'h2,   // reg_c_read = window index C
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h1,   // micro_branch = terminate
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_SHL = {
        5'hB,   // alu_op = shl
        4'h0,   // reg_a_write = window index A
        4'h1,   // reg_b_read = window index B
        4'h2,   // reg_c_read = window index C
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h1,   // micro_branch = terminate
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_SHR = {
        5'hC,   // alu_op = shr
        4'h0,   // reg_a_write = window index A
        4'h1,   // reg_b_read = window index B
        4'h2,   // reg_c_read = window index C
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h1,   // micro_branch = terminate
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_MOD = {
        5'h14,  // alu_op = mod
        4'h0,   // reg_a_write = window index A
        4'h1,   // reg_b_read = window index B
        4'h2,   // reg_c_read = window index C
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h1,   // micro_branch = terminate
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_POW = {
        5'h15,  // alu_op = pow
        4'h0,   // reg_a_write = window index A
        4'h1,   // reg_b_read = window index B
        4'h2,   // reg_c_read = window index C
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h1,   // micro_branch = terminate
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_IDIV = {
        5'h16,  // alu_op = idiv
        4'h0,   // reg_a_write = window index A
        4'h1,   // reg_b_read = window index B
        4'h2,   // reg_c_read = window index C
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h1,   // micro_branch = terminate
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_LEN = {
        5'hD,   // alu_op = len
        4'h0,   // reg_a_write = window index A
        4'h1,   // reg_b_read = window index B
        4'h0,   // reg_c_read = unused
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h1,   // micro_branch = terminate
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_JMP = {
        5'h0,   // alu_op = pass
        4'h0,   // reg_a_write = window index A
        4'h0,   // reg_b_read = unused
        4'h0,   // reg_c_read = unused
        3'h0,   // mem_op = no access
        3'h2,   // pc_op = jump offset
        2'h1,   // micro_branch = terminate
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = placeholder
    };

    localparam [63:0] OP_TEST = {
        5'hE,   // alu_op = test
        4'h0,   // reg_a_write = window index A
        4'h1,   // reg_b_read = window index A
        4'h0,   // reg_c_read = unused
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h2,   // micro_branch = conditional
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_EQ = {
        5'hF,   // alu_op = compare
        4'h0,   // reg_a_write = window index A
        4'h1,   // reg_b_read = window index B
        4'h2,   // reg_c_read = window index C
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h2,   // micro_branch = conditional
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_LT = {
        5'h10,  // alu_op = compare lt
        4'h0,   // reg_a_write = window index A
        4'h1,   // reg_b_read = window index B
        4'h2,   // reg_c_read = window index C
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h2,   // micro_branch = conditional
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_LE = {
        5'h17,  // alu_op = compare le
        4'h0,   // reg_a_write = window index A
        4'h1,   // reg_b_read = window index B
        4'h2,   // reg_c_read = window index C
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h2,   // micro_branch = conditional
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_GETTABLE = {
        5'h0,   // alu_op = pass
        4'h0,   // reg_a_write = window index A
        4'h1,   // reg_b_read = window index B
        4'h2,   // reg_c_read = window index C
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h0,   // micro_branch = continue
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_GETTABLE_DONE = {
        5'h0,   // alu_op = pass
        4'h0,   // reg_a_write = window index A
        4'h0,   // reg_b_read = unused
        4'h0,   // reg_c_read = unused
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h1,   // micro_branch = terminate
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_SETTABLE = {
        5'h0,   // alu_op = pass
        4'h0,   // reg_a_write = window index A
        4'h1,   // reg_b_read = window index B
        4'h2,   // reg_c_read = window index C
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h0,   // micro_branch = continue
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_SETTABLE_DONE = {
        5'h0,   // alu_op = pass
        4'h0,   // reg_a_write = window index A
        4'h0,   // reg_b_read = unused
        4'h0,   // reg_c_read = unused
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h1,   // micro_branch = terminate
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_CALL = {
        5'h0,   // alu_op = pass
        4'h0,   // reg_a_write = window index A
        4'h1,   // reg_b_read = window index B
        4'h2,   // reg_c_read = window index C
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h0,   // micro_branch = continue
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_CALL_DONE = {
        5'h0,   // alu_op = pass
        4'h0,   // reg_a_write = window index A
        4'h0,   // reg_b_read = unused
        4'h0,   // reg_c_read = unused
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h1,   // micro_branch = terminate
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_RETURN = {
        5'h0,   // alu_op = pass
        4'h0,   // reg_a_write = window index A
        4'h1,   // reg_b_read = window index B
        4'h2,   // reg_c_read = window index C
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h0,   // micro_branch = continue
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_RETURN_DONE = {
        5'h0,   // alu_op = pass
        4'h0,   // reg_a_write = window index A
        4'h0,   // reg_b_read = unused
        4'h0,   // reg_c_read = unused
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h1,   // micro_branch = terminate
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_RETURN0 = {
        5'h0,   // alu_op = pass
        4'h0,   // reg_a_write = window index A
        4'h0,   // reg_b_read = unused
        4'h0,   // reg_c_read = unused
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h1,   // micro_branch = terminate
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_RETURN1 = {
        5'h0,   // alu_op = pass
        4'h0,   // reg_a_write = window index A
        4'h0,   // reg_b_read = unused
        4'h0,   // reg_c_read = unused
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h1,   // micro_branch = terminate
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_TAILCALL = {
        5'h0,   // alu_op = pass
        4'h0,   // reg_a_write = window index A
        4'h1,   // reg_b_read = window index B
        4'h2,   // reg_c_read = window index C
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h0,   // micro_branch = continue
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_TAILCALL_DONE = {
        5'h0,   // alu_op = pass
        4'h0,   // reg_a_write = window index A
        4'h0,   // reg_b_read = unused
        4'h0,   // reg_c_read = unused
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h1,   // micro_branch = terminate
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_CLOSURE = {
        5'h0,   // alu_op = pass
        4'h0,   // reg_a_write = window index A
        4'h1,   // reg_b_read = window index B
        4'h0,   // reg_c_read = unused
        3'h2,   // mem_op = read proto
        3'h0,   // pc_op = no change
        2'h0,   // micro_branch = continue
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_CLOSURE_DONE = {
        5'h0,   // alu_op = pass
        4'h0,   // reg_a_write = window index A
        4'h0,   // reg_b_read = unused
        4'h0,   // reg_c_read = unused
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h1,   // micro_branch = terminate
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_NEWTABLE = {
        5'h0,   // alu_op = pass
        4'h0,   // reg_a_write = window index A
        4'h0,   // reg_b_read = unused
        4'h0,   // reg_c_read = unused
        3'h3,   // mem_op = write object
        3'h0,   // pc_op = no change
        2'h0,   // micro_branch = continue
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_NEWTABLE_DONE = {
        5'h0,   // alu_op = pass
        4'h0,   // reg_a_write = window index A
        4'h0,   // reg_b_read = unused
        4'h0,   // reg_c_read = unused
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h1,   // micro_branch = terminate
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_GETUPVAL = {
        5'h0,   // alu_op = pass
        4'h0,   // reg_a_write = window index A
        4'h1,   // reg_b_read = window index B
        4'h0,   // reg_c_read = unused
        3'h4,   // mem_op = read upvalue
        3'h0,   // pc_op = no change
        2'h0,   // micro_branch = continue
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_GETUPVAL_DONE = {
        5'h0,   // alu_op = pass
        4'h0,   // reg_a_write = window index A
        4'h0,   // reg_b_read = unused
        4'h0,   // reg_c_read = unused
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h1,   // micro_branch = terminate
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_SETUPVAL = {
        5'h0,   // alu_op = pass
        4'h0,   // reg_a_write = window index A
        4'h1,   // reg_b_read = window index B
        4'h0,   // reg_c_read = unused
        3'h5,   // mem_op = write upvalue
        3'h0,   // pc_op = no change
        2'h0,   // micro_branch = continue
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_SETUPVAL_DONE = {
        5'h0,   // alu_op = pass
        4'h0,   // reg_a_write = window index A
        4'h0,   // reg_b_read = unused
        4'h0,   // reg_c_read = unused
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h1,   // micro_branch = terminate
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_SELF = {
        5'h0,   // alu_op = pass
        4'h0,   // reg_a_write = window index A
        4'h1,   // reg_b_read = window index B
        4'h2,   // reg_c_read = window index C
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h0,   // micro_branch = continue
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_SELF_DONE = {
        5'h0,   // alu_op = pass
        4'h0,   // reg_a_write = window index A
        4'h0,   // reg_b_read = unused
        4'h0,   // reg_c_read = unused
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h1,   // micro_branch = terminate
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_CONCAT = {
        5'h11,  // alu_op = concat
        4'h0,   // reg_a_write = window index A
        4'h1,   // reg_b_read = window index B
        4'h0,   // reg_c_read = unused
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h1,   // micro_branch = terminate
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_CLOSE = {
        5'h0,   // alu_op = pass
        4'h0,   // reg_a_write = window index A
        4'h1,   // reg_b_read = window index B
        4'h0,   // reg_c_read = unused
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h1,   // micro_branch = terminate
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_TBC = {
        5'h0,   // alu_op = pass
        4'h0,   // reg_a_write = window index A
        4'h1,   // reg_b_read = window index B
        4'h0,   // reg_c_read = unused
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h1,   // micro_branch = terminate
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_FORLOOP = {
        5'h12,  // alu_op = forloop
        4'h0,   // reg_a_write = window index A
        4'h1,   // reg_b_read = window index B
        4'h2,   // reg_c_read = window index C
        3'h0,   // mem_op = no access
        3'h2,   // pc_op = jump offset
        2'h2,   // micro_branch = conditional
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = placeholder
    };

    localparam [63:0] OP_FORPREP = {
        5'h13,
        4'h0,
        4'h1,
        4'h2,
        3'h0,
        3'h1,
        2'h2,
        2'h0,
        2'h0,
        1'h1,
        34'h0
    };

    localparam [63:0] OP_TFORPREP = {
        5'h0,
        4'h0,
        4'h1,
        4'h0,
        3'h0,
        3'h1,
        2'h1,
        2'h0,
        2'h0,
        1'h1,
        34'h0
    };

    localparam [63:0] OP_TFORCALL = {
        5'h0,   // alu_op = pass
        4'h0,   // reg_a_write = window index A
        4'h1,   // reg_b_read = window index B
        4'h2,   // reg_c_read = window index C
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h1,   // micro_branch = terminate
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_TFORLOOP = {
        5'h0,   // alu_op = pass
        4'h0,   // reg_a_write = window index A
        4'h2,   // reg_b_read = window index A+2
        4'h0,   // reg_c_read = unused
        3'h0,   // mem_op = no access
        3'h2,   // pc_op = jump offset
        2'h2,   // micro_branch = conditional
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = placeholder
    };

    localparam [63:0] OP_SETLIST = {
        5'h0,   // alu_op = pass
        4'h0,   // reg_a_write = window index A
        4'h1,   // reg_b_read = window index B
        4'h2,   // reg_c_read = window index C
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h0,   // micro_branch = continue
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_SETLIST_DONE = {
        5'h0,   // alu_op = pass
        4'h0,   // reg_a_write = window index A
        4'h0,   // reg_b_read = unused
        4'h0,   // reg_c_read = unused
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h1,   // micro_branch = terminate
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_VARARG = {
        5'h0,   // alu_op = pass
        4'h0,   // reg_a_write = window index A
        4'h1,   // reg_b_read = window index B
        4'h2,   // reg_c_read = window index C
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h1,   // micro_branch = terminate
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_VARARGPREP = {
        5'h0,   // alu_op = pass
        4'h0,   // reg_a_write = window index A
        4'h0,   // reg_b_read = unused
        4'h0,   // reg_c_read = unused
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h1,   // micro_branch = terminate
        2'h0,   // gc_step = no GC
        2'h1,   // stack_op = advance
        1'h1,   // enable = 1
        34'h0   // immediate = placeholder
    };

    localparam [63:0] OP_EXTRAARG = {
        5'h0,   // alu_op = pass
        4'h0,   // reg_a_write = window index A
        4'h0,   // reg_b_read = unused
        4'h0,   // reg_c_read = unused
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h1,   // micro_branch = terminate
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = placeholder
    };

    localparam [63:0] NOP = {
        5'h0,   // alu_op = pass
        4'h0,   // reg_a_write = unused
        4'h0,   // reg_b_read = unused
        4'h0,   // reg_c_read = unused
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h1,   // micro_branch = terminate
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h0,   // enable = 0 (NOP)
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_ADDI = {
        5'h1,   // alu_op = add
        4'h0,   // reg_a_write = window index A
        4'h1,   // reg_b_read = window index B
        4'h0,   // reg_c_read = unused
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h1,   // micro_branch = terminate
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = placeholder
    };

    localparam [63:0] OP_ADDK = {
        5'h1,   // alu_op = add
        4'h0,   // reg_a_write = window index A
        4'h1,   // reg_b_read = window index B
        4'h3,   // reg_c_read = ktable index
        3'h1,   // mem_op = read ktable
        3'h0,   // pc_op = no change
        2'h0,   // micro_branch = continue
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_ADDK_DONE = {
        5'h1,   // alu_op = add
        4'h0,   // reg_a_write = window index A
        4'h1,   // reg_b_read = window index B
        4'h3,   // reg_c_read = ktable index
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h1,   // micro_branch = terminate
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_SUBK = {
        5'h2,   // alu_op = sub
        4'h0,   // reg_a_write = window index A
        4'h1,   // reg_b_read = window index B
        4'h3,   // reg_c_read = ktable index
        3'h1,   // mem_op = read ktable
        3'h0,   // pc_op = no change
        2'h0,   // micro_branch = continue
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_SUBK_DONE = {
        5'h2,   // alu_op = sub
        4'h0,   // reg_a_write = window index A
        4'h1,   // reg_b_read = window index B
        4'h3,   // reg_c_read = ktable index
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h1,   // micro_branch = terminate
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_MULK = {
        5'h3,   // alu_op = mul
        4'h0,   // reg_a_write = window index A
        4'h1,   // reg_b_read = window index B
        4'h3,   // reg_c_read = ktable index
        3'h1,   // mem_op = read ktable
        3'h0,   // pc_op = no change
        2'h0,   // micro_branch = continue
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_MULK_DONE = {
        5'h3,   // alu_op = mul
        4'h0,   // reg_a_write = window index A
        4'h1,   // reg_b_read = window index B
        4'h3,   // reg_c_read = ktable index
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h1,   // micro_branch = terminate
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_MODK = {
        5'h14,  // alu_op = mod
        4'h0,   // reg_a_write = window index A
        4'h1,   // reg_b_read = window index B
        4'h3,   // reg_c_read = ktable index
        3'h1,   // mem_op = read ktable
        3'h0,   // pc_op = no change
        2'h0,   // micro_branch = continue
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_MODK_DONE = {
        5'h14,  // alu_op = mod
        4'h0,   // reg_a_write = window index A
        4'h1,   // reg_b_read = window index B
        4'h3,   // reg_c_read = ktable index
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h1,   // micro_branch = terminate
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_POWK = {
        5'h15,  // alu_op = pow
        4'h0,   // reg_a_write = window index A
        4'h1,   // reg_b_read = window index B
        4'h3,   // reg_c_read = ktable index
        3'h1,   // mem_op = read ktable
        3'h0,   // pc_op = no change
        2'h0,   // micro_branch = continue
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_POWK_DONE = {
        5'h15,  // alu_op = pow
        4'h0,   // reg_a_write = window index A
        4'h1,   // reg_b_read = window index B
        4'h3,   // reg_c_read = ktable index
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h1,   // micro_branch = terminate
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_DIVK = {
        5'h4,   // alu_op = div
        4'h0,   // reg_a_write = window index A
        4'h1,   // reg_b_read = window index B
        4'h3,   // reg_c_read = ktable index
        3'h1,   // mem_op = read ktable
        3'h0,   // pc_op = no change
        2'h0,   // micro_branch = continue
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_DIVK_DONE = {
        5'h4,   // alu_op = div
        4'h0,   // reg_a_write = window index A
        4'h1,   // reg_b_read = window index B
        4'h3,   // reg_c_read = ktable index
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h1,   // micro_branch = terminate
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_IDIVK = {
        5'h16,  // alu_op = idiv
        4'h0,   // reg_a_write = window index A
        4'h1,   // reg_b_read = window index B
        4'h3,   // reg_c_read = ktable index
        3'h1,   // mem_op = read ktable
        3'h0,   // pc_op = no change
        2'h0,   // micro_branch = continue
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_IDIVK_DONE = {
        5'h16,  // alu_op = idiv
        4'h0,   // reg_a_write = window index A
        4'h1,   // reg_b_read = window index B
        4'h3,   // reg_c_read = ktable index
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h1,   // micro_branch = terminate
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_BANDK = {
        5'h8,   // alu_op = and
        4'h0,   // reg_a_write = window index A
        4'h1,   // reg_b_read = window index B
        4'h3,   // reg_c_read = ktable index
        3'h1,   // mem_op = read ktable
        3'h0,   // pc_op = no change
        2'h0,   // micro_branch = continue
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_BANDK_DONE = {
        5'h8,   // alu_op = and
        4'h0,   // reg_a_write = window index A
        4'h1,   // reg_b_read = window index B
        4'h3,   // reg_c_read = ktable index
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h1,   // micro_branch = terminate
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_BORK = {
        5'h9,   // alu_op = or
        4'h0,   // reg_a_write = window index A
        4'h1,   // reg_b_read = window index B
        4'h3,   // reg_c_read = ktable index
        3'h1,   // mem_op = read ktable
        3'h0,   // pc_op = no change
        2'h0,   // micro_branch = continue
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_BORK_DONE = {
        5'h9,   // alu_op = or
        4'h0,   // reg_a_write = window index A
        4'h1,   // reg_b_read = window index B
        4'h3,   // reg_c_read = ktable index
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h1,   // micro_branch = terminate
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_BXORK = {
        5'hA,   // alu_op = xor
        4'h0,   // reg_a_write = window index A
        4'h1,   // reg_b_read = window index B
        4'h3,   // reg_c_read = ktable index
        3'h1,   // mem_op = read ktable
        3'h0,   // pc_op = no change
        2'h0,   // micro_branch = continue
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_BXORK_DONE = {
        5'hA,   // alu_op = xor
        4'h0,   // reg_a_write = window index A
        4'h1,   // reg_b_read = window index B
        4'h3,   // reg_c_read = ktable index
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h1,   // micro_branch = terminate
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_SHRI = {
        5'hC,   // alu_op = shr
        4'h0,   // reg_a_write = window index A
        4'h1,   // reg_b_read = window index B
        4'h0,   // reg_c_read = unused
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h1,   // micro_branch = terminate
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = placeholder
    };

    localparam [63:0] OP_SHLI = {
        5'hB,   // alu_op = shl
        4'h0,   // reg_a_write = window index A
        4'h1,   // reg_b_read = window index B
        4'h0,   // reg_c_read = unused
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h1,   // micro_branch = terminate
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = placeholder
    };

    localparam [63:0] OP_GETI = {
        5'h0,   // alu_op = pass
        4'h0,   // reg_a_write = window index A
        4'h1,   // reg_b_read = window index B
        4'h2,   // reg_c_read = window index C
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h0,   // micro_branch = continue
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_GETI_DONE = {
        5'h0,   // alu_op = pass
        4'h0,   // reg_a_write = window index A
        4'h0,   // reg_b_read = unused
        4'h0,   // reg_c_read = unused
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h1,   // micro_branch = terminate
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_SETI = {
        5'h0,   // alu_op = pass
        4'h0,   // reg_a_write = window index A
        4'h1,   // reg_b_read = window index B
        4'h2,   // reg_c_read = window index C
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h0,   // micro_branch = continue
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_SETI_DONE = {
        5'h0,   // alu_op = pass
        4'h0,   // reg_a_write = window index A
        4'h0,   // reg_b_read = unused
        4'h0,   // reg_c_read = unused
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h1,   // micro_branch = terminate
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_GETFIELD = {
        5'h0,   // alu_op = pass
        4'h0,   // reg_a_write = window index A
        4'h1,   // reg_b_read = window index B
        4'h3,   // reg_c_read = ktable index
        3'h1,   // mem_op = read ktable
        3'h0,   // pc_op = no change
        2'h0,   // micro_branch = continue
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_GETFIELD_DONE = {
        5'h0,   // alu_op = pass
        4'h0,   // reg_a_write = window index A
        4'h0,   // reg_b_read = unused
        4'h0,   // reg_c_read = unused
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h1,   // micro_branch = terminate
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_SETFIELD = {
        5'h0,   // alu_op = pass
        4'h0,   // reg_a_write = window index A
        4'h1,   // reg_b_read = window index B
        4'h3,   // reg_c_read = ktable index
        3'h1,   // mem_op = read ktable
        3'h0,   // pc_op = no change
        2'h0,   // micro_branch = continue
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_SETFIELD_DONE = {
        5'h0,   // alu_op = pass
        4'h0,   // reg_a_write = window index A
        4'h0,   // reg_b_read = unused
        4'h0,   // reg_c_read = unused
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h1,   // micro_branch = terminate
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_GETTABUP = {
        5'h0,   // alu_op = pass
        4'h0,   // reg_a_write = window index A
        4'h1,   // reg_b_read = window index B
        4'h3,   // reg_c_read = ktable index
        3'h4,   // mem_op = read upvalue
        3'h0,   // pc_op = no change
        2'h0,   // micro_branch = continue
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_GETTABUP_DONE = {
        5'h0,   // alu_op = pass
        4'h0,   // reg_a_write = window index A
        4'h0,   // reg_b_read = unused
        4'h0,   // reg_c_read = unused
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h1,   // micro_branch = terminate
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_SETTABUP = {
        5'h0,   // alu_op = pass
        4'h0,   // reg_a_write = window index A
        4'h1,   // reg_b_read = window index B
        4'h3,   // reg_c_read = ktable index
        3'h4,   // mem_op = read upvalue
        3'h0,   // pc_op = no change
        2'h0,   // micro_branch = continue
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_SETTABUP_DONE = {
        5'h0,   // alu_op = pass
        4'h0,   // reg_a_write = window index A
        4'h0,   // reg_b_read = unused
        4'h0,   // reg_c_read = unused
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h1,   // micro_branch = terminate
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_EQK = {
        5'hF,   // alu_op = compare
        4'h0,   // reg_a_write = window index A
        4'h1,   // reg_b_read = window index B
        4'h3,   // reg_c_read = ktable index
        3'h1,   // mem_op = read ktable
        3'h0,   // pc_op = no change
        2'h0,   // micro_branch = continue
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_EQK_DONE = {
        5'hF,   // alu_op = compare
        4'h0,   // reg_a_write = window index A
        4'h1,   // reg_b_read = window index B
        4'h3,   // reg_c_read = ktable index
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h2,   // micro_branch = conditional
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_EQI = {
        5'hF,   // alu_op = compare
        4'h0,   // reg_a_write = window index A
        4'h1,   // reg_b_read = window index B
        4'h0,   // reg_c_read = unused
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h2,   // micro_branch = conditional
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = placeholder
    };

    localparam [63:0] OP_LTI = {
        5'h10,  // alu_op = compare lt
        4'h0,   // reg_a_write = window index A
        4'h1,   // reg_b_read = window index B
        4'h0,   // reg_c_read = unused
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h2,   // micro_branch = conditional
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = placeholder
    };

    localparam [63:0] OP_LEI = {
        5'h17,  // alu_op = compare le
        4'h0,   // reg_a_write = window index A
        4'h1,   // reg_b_read = window index B
        4'h0,   // reg_c_read = unused
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h2,   // micro_branch = conditional
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = placeholder
    };

    localparam [63:0] OP_GTI = {
        5'h18,  // alu_op = compare gt
        4'h0,   // reg_a_write = window index A
        4'h1,   // reg_b_read = window index B
        4'h0,   // reg_c_read = unused
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h2,   // micro_branch = conditional
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = placeholder
    };

    localparam [63:0] OP_GEI = {
        5'h19,  // alu_op = compare ge
        4'h0,   // reg_a_write = window index A
        4'h1,   // reg_b_read = window index B
        4'h0,   // reg_c_read = unused
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h2,   // micro_branch = conditional
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = placeholder
    };

    localparam [63:0] OP_TESTSET = {
        5'hE,   // alu_op = test
        4'h0,   // reg_a_write = window index A
        4'h1,   // reg_b_read = window index B
        4'h0,   // reg_c_read = unused
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h2,   // micro_branch = conditional
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_MMBIN = {
        5'h0,   // alu_op = pass
        4'h0,   // reg_a_write = window index A
        4'h1,   // reg_b_read = window index B
        4'h2,   // reg_c_read = window index C
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h1,   // micro_branch = terminate
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_MMBINI = {
        5'h0,   // alu_op = pass
        4'h0,   // reg_a_write = window index A
        4'h1,   // reg_b_read = window index B
        4'h0,   // reg_c_read = unused
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h1,   // micro_branch = terminate
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = placeholder
    };

    localparam [63:0] OP_MMBINK = {
        5'h0,   // alu_op = pass
        4'h0,   // reg_a_write = window index A
        4'h1,   // reg_b_read = window index B
        4'h3,   // reg_c_read = ktable index
        3'h1,   // mem_op = read ktable
        3'h0,   // pc_op = no change
        2'h0,   // micro_branch = continue
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_MMBINK_DONE = {
        5'h0,   // alu_op = pass
        4'h0,   // reg_a_write = window index A
        4'h1,   // reg_b_read = window index B
        4'h3,   // reg_c_read = ktable index
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h1,   // micro_branch = terminate
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_LOADKX = {
        5'h0,   // alu_op = pass
        4'h0,   // reg_a_write = window index A
        4'h0,   // reg_b_read = unused
        4'h3,   // reg_c_read = ktable index
        3'h1,   // mem_op = read ktable
        3'h0,   // pc_op = no change
        2'h0,   // micro_branch = continue
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam [63:0] OP_LOADKX_DONE = {
        5'h0,   // alu_op = pass
        4'h0,   // reg_a_write = window index A
        4'h0,   // reg_b_read = unused
        4'h0,   // reg_c_read = unused
        3'h0,   // mem_op = no access
        3'h0,   // pc_op = no change
        2'h1,   // micro_branch = terminate
        2'h0,   // gc_step = no GC
        2'h0,   // stack_op = no change
        1'h1,   // enable = 1
        34'h0   // immediate = 0
    };

    localparam DONE_OFFSET = 512;

    reg [ROM_WIDTH-1:0] rom_array [0:ROM_DEPTH-1];

    initial begin
        for (int i = 0; i < ROM_DEPTH; i++) begin
            rom_array[i] = NOP;
        end

        rom_array[0]  = OP_MOVE;
        rom_array[0 + DONE_OFFSET] = OP_MOVE_DONE;
        rom_array[1]  = OP_LOADI;
        rom_array[2]  = OP_LOADF;
        rom_array[3]  = OP_LOADK;
        rom_array[3 + DONE_OFFSET] = OP_LOADK_DONE;
        rom_array[4]  = OP_LOADKX;
        rom_array[4 + DONE_OFFSET] = OP_LOADKX_DONE;
        rom_array[5]  = OP_LOADFALSE;
        rom_array[6]  = OP_LFALSESKIP;
        rom_array[7]  = OP_LOADTRUE;
        rom_array[8]  = OP_LOADNIL;
        rom_array[8 + DONE_OFFSET] = OP_LOADNIL_STEP;
        rom_array[8 + 2 * DONE_OFFSET] = OP_LOADNIL_DONE;
        rom_array[9]  = OP_GETUPVAL;
        rom_array[9 + DONE_OFFSET] = OP_GETUPVAL_DONE;
        rom_array[10] = OP_SETUPVAL;
        rom_array[10 + DONE_OFFSET] = OP_SETUPVAL_DONE;
        rom_array[11] = OP_GETTABUP;
        rom_array[11 + DONE_OFFSET] = OP_GETTABUP_DONE;
        rom_array[12] = OP_GETTABLE;
        rom_array[12 + DONE_OFFSET] = OP_GETTABLE_DONE;
        rom_array[13] = OP_GETI;
        rom_array[13 + DONE_OFFSET] = OP_GETI_DONE;
        rom_array[14] = OP_GETFIELD;
        rom_array[14 + DONE_OFFSET] = OP_GETFIELD_DONE;
        rom_array[15] = OP_SETTABUP;
        rom_array[15 + DONE_OFFSET] = OP_SETTABUP_DONE;
        rom_array[16] = OP_SETTABLE;
        rom_array[16 + DONE_OFFSET] = OP_SETTABLE_DONE;
        rom_array[17] = OP_SETI;
        rom_array[17 + DONE_OFFSET] = OP_SETI_DONE;
        rom_array[18] = OP_SETFIELD;
        rom_array[18 + DONE_OFFSET] = OP_SETFIELD_DONE;
        rom_array[19] = OP_NEWTABLE;
        rom_array[19 + DONE_OFFSET] = OP_NEWTABLE_DONE;
        rom_array[20] = OP_SELF;
        rom_array[20 + DONE_OFFSET] = OP_SELF_DONE;
        rom_array[21] = OP_ADDI;
        rom_array[22] = OP_ADDK;
        rom_array[22 + DONE_OFFSET] = OP_ADDK_DONE;
        rom_array[23] = OP_SUBK;
        rom_array[23 + DONE_OFFSET] = OP_SUBK_DONE;
        rom_array[24] = OP_MULK;
        rom_array[24 + DONE_OFFSET] = OP_MULK_DONE;
        rom_array[25] = OP_MODK;
        rom_array[25 + DONE_OFFSET] = OP_MODK_DONE;
        rom_array[26] = OP_POWK;
        rom_array[26 + DONE_OFFSET] = OP_POWK_DONE;
        rom_array[27] = OP_DIVK;
        rom_array[27 + DONE_OFFSET] = OP_DIVK_DONE;
        rom_array[28] = OP_IDIVK;
        rom_array[28 + DONE_OFFSET] = OP_IDIVK_DONE;
        rom_array[29] = OP_BANDK;
        rom_array[29 + DONE_OFFSET] = OP_BANDK_DONE;
        rom_array[30] = OP_BORK;
        rom_array[30 + DONE_OFFSET] = OP_BORK_DONE;
        rom_array[31] = OP_BXORK;
        rom_array[31 + DONE_OFFSET] = OP_BXORK_DONE;
        rom_array[32] = OP_SHRI;
        rom_array[33] = OP_SHLI;
        rom_array[34] = OP_ADD;
        rom_array[35] = OP_SUB;
        rom_array[36] = OP_MUL;
        rom_array[37] = OP_MOD;
        rom_array[38] = OP_POW;
        rom_array[39] = OP_DIV;
        rom_array[40] = OP_IDIV;
        rom_array[41] = OP_BAND;
        rom_array[42] = OP_BOR;
        rom_array[43] = OP_BXOR;
        rom_array[44] = OP_SHL;
        rom_array[45] = OP_SHR;
        rom_array[46] = OP_MMBIN;
        rom_array[47] = OP_MMBINI;
        rom_array[48] = OP_MMBINK;
        rom_array[48 + DONE_OFFSET] = OP_MMBINK_DONE;
        rom_array[49] = OP_UNM;
        rom_array[50] = OP_BNOT;
        rom_array[51] = OP_NOT;
        rom_array[52] = OP_LEN;
        rom_array[53] = OP_CONCAT;
        rom_array[54] = OP_CLOSE;
        rom_array[55] = OP_TBC;
        rom_array[56] = OP_JMP;
        rom_array[57] = OP_EQ;
        rom_array[58] = OP_LT;
        rom_array[59] = OP_LE;
        rom_array[60] = OP_EQK;
        rom_array[60 + DONE_OFFSET] = OP_EQK_DONE;
        rom_array[61] = OP_EQI;
        rom_array[62] = OP_LTI;
        rom_array[63] = OP_LEI;
        rom_array[64] = OP_GTI;
        rom_array[65] = OP_GEI;
        rom_array[66] = OP_TEST;
        rom_array[67] = OP_TESTSET;
        rom_array[68] = OP_CALL;
        rom_array[68 + DONE_OFFSET] = OP_CALL_DONE;
        rom_array[69] = OP_TAILCALL;
        rom_array[69 + DONE_OFFSET] = OP_TAILCALL_DONE;
        rom_array[70] = OP_RETURN;
        rom_array[70 + DONE_OFFSET] = OP_RETURN_DONE;
        rom_array[71] = OP_RETURN0;
        rom_array[72] = OP_RETURN1;
        rom_array[73] = OP_FORLOOP;
        rom_array[74] = OP_FORPREP;
        rom_array[75] = OP_TFORPREP;
        rom_array[76] = OP_TFORCALL;
        rom_array[77] = OP_TFORLOOP;
        rom_array[78] = OP_SETLIST;
        rom_array[78 + DONE_OFFSET] = OP_SETLIST_DONE;
        rom_array[79] = OP_CLOSURE;
        rom_array[79 + DONE_OFFSET] = OP_CLOSURE_DONE;
        rom_array[80] = OP_VARARG;
        rom_array[81] = OP_VARARGPREP;
        rom_array[82] = OP_EXTRAARG;
    end

    assign data = rom_array[address];

endmodule
