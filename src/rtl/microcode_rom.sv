/* verilator lint_off WIDTHEXPAND */
module microcode_rom #(
    parameter INSTRUCTIONS = 128,
    parameter ROM_DEPTH = INSTRUCTIONS * 4
)(
    input  wire clk,
    input  wire [6:0] opcode,
    input  wire [1:0] step,
    output wire [4:0] alu_op,
    output wire [1:0] alu_optype,
    output wire [3:0] dest,
    output wire next_microop,
    output wire [4:0] operand_a_sel,
    output wire [4:0] operand_b_sel,
    output wire [2:0] pc_op,
    output wire [1:0] stack_op
);

    localparam STEP = INSTRUCTIONS;

    reg [26:0] rom_array [0:ROM_DEPTH-1];

    initial begin
        for (integer i = 0; i < ROM_DEPTH; i = i + 1) begin
            rom_array[i] = {ALU_PASS, ALUOPTYPE_NORMAL, DEST_NONE, 1'h0, SOURCE_ZERO, SOURCE_ZERO, PC_ADVANCE, 2'h0}; // MC_NOP;
        end

        rom_array[OP_MOVE]            = {ALU_PASS,   ALUOPTYPE_NORMAL, DEST_REG_A,         1'h0, SOURCE_REG_B,     SOURCE_ZERO, PC_ADVANCE, 2'h0};
        rom_array[OP_LOADI]           = {ALU_PASS,   ALUOPTYPE_NORMAL, DEST_REG_A,         1'h0, SOURCE_SC,        SOURCE_ZERO, PC_ADVANCE, 2'h0};
        rom_array[OP_LOADF]           = {ALU_PASS,   ALUOPTYPE_NORMAL, DEST_REG_A,         1'h0, SOURCE_FC,        SOURCE_ZERO, PC_ADVANCE, 2'h0};
        rom_array[OP_LOADK]           = {ALU_PASS,   ALUOPTYPE_NORMAL, DEST_REG_A,         1'h0, SOURCE_K_C,       SOURCE_ZERO, PC_ADVANCE, 2'h0};
        rom_array[OP_LOADKX]          = {ALU_PASS,   ALUOPTYPE_NORMAL, DEST_REG_A,         1'h0, SOURCE_K_EXTRA,   SOURCE_ZERO, PC_ADVANCE, 2'h0};
        rom_array[OP_LOADTRUE]        = {ALU_TRUE,   ALUOPTYPE_NORMAL, DEST_REG_A,         1'h0, SOURCE_ZERO,      SOURCE_ZERO, PC_ADVANCE, 2'h0};
        rom_array[OP_LOADFALSE]       = {ALU_FALSE,  ALUOPTYPE_NORMAL, DEST_REG_A,         1'h0, SOURCE_ZERO,      SOURCE_ZERO, PC_ADVANCE, 2'h0};
        rom_array[OP_LFALSESKIP]      = {ALU_FALSE,  ALUOPTYPE_NORMAL, DEST_REG_A,         1'h0, SOURCE_ZERO,      SOURCE_ZERO, PC_SKIP,    2'h0};
        rom_array[OP_LOADNIL]         = {ALU_NIL,    ALUOPTYPE_NORMAL, DEST_REG_A_UNTIL_B, 1'h0, SOURCE_ZERO,      SOURCE_ZERO, PC_ADVANCE, 2'h0};
        rom_array[OP_GETUPVAL]        = {ALU_PASS,   ALUOPTYPE_NORMAL, DEST_REG_A,         1'h0, SOURCE_UPVALUE_B, SOURCE_ZERO, PC_ADVANCE, 2'h0};
        rom_array[OP_SETUPVAL]        = {ALU_PASS,   ALUOPTYPE_NORMAL, DEST_UPVALUE_B,     1'h0, SOURCE_REG_A,     SOURCE_ZERO, PC_ADVANCE, 2'h0};
        
        rom_array[OP_GETTABUP]        = {ALU_PASS,   ALUOPTYPE_NORMAL, DEST_TEMPTABLE,     1'h1, SOURCE_UPVALUE_B, SOURCE_ZERO, PC_IDLE,    2'h0};
        rom_array[OP_GETTABUP + STEP] = {ALU_PASS,   ALUOPTYPE_NORMAL, DEST_REG_A,         1'h0, SOURCE_TEMP_K_C,  SOURCE_ZERO, PC_ADVANCE, 2'h0};
        
        rom_array[OP_GETTABLE]        = {ALU_PASS,   ALUOPTYPE_NORMAL, DEST_TEMPTABLE,     1'h1, SOURCE_REG_B,      SOURCE_ZERO, PC_IDLE,    2'h0};
        rom_array[OP_GETTABLE + STEP] = {ALU_PASS,   ALUOPTYPE_NORMAL, DEST_REG_A,         1'h0, SOURCE_TEMP_REG_C, SOURCE_ZERO, PC_ADVANCE, 2'h0};
        
        rom_array[OP_GETI]            = {ALU_PASS,   ALUOPTYPE_NORMAL, DEST_TEMPTABLE,     1'h1, SOURCE_REG_A,     SOURCE_ZERO, PC_IDLE,    2'h0};
        rom_array[OP_GETI + STEP]     = {ALU_PASS,   ALUOPTYPE_NORMAL, DEST_TEMPTABLE,     1'h1, SOURCE_TEMP_B,    SOURCE_ZERO, PC_IDLE,    2'h0};
        rom_array[OP_GETI + 2 * STEP] = {ALU_PASS,   ALUOPTYPE_NORMAL, DEST_REG_A,         1'h0, SOURCE_REGK_C,    SOURCE_ZERO, PC_ADVANCE, 2'h0};
        
        rom_array[OP_GETFIELD]        = {ALU_PASS,   ALUOPTYPE_NORMAL, DEST_TEMPTABLE,     1'h1, SOURCE_REG_B,     SOURCE_ZERO, PC_IDLE,    2'h0};
        rom_array[OP_GETFIELD + STEP] = {ALU_PASS,   ALUOPTYPE_NORMAL, DEST_REG_A,         1'h0, SOURCE_TEMP_K_C,  SOURCE_ZERO, PC_ADVANCE, 2'h0};
        
        rom_array[OP_SETTABUP]        = {ALU_PASS,   ALUOPTYPE_NORMAL, DEST_TEMPTABLE,     1'h1, SOURCE_UPVALUE_A, SOURCE_ZERO, PC_IDLE,    2'h0};
        rom_array[OP_SETTABUP + STEP] = {ALU_PASS,   ALUOPTYPE_NORMAL, DEST_TEMP_K_B,      1'h0, SOURCE_REGK_C,    SOURCE_ZERO, PC_ADVANCE, 2'h0};
        
        rom_array[OP_SETTABLE]        = {ALU_PASS,   ALUOPTYPE_NORMAL, DEST_TEMPTABLE,     1'h1, SOURCE_REG_A,     SOURCE_ZERO, PC_IDLE,    2'h0};
        rom_array[OP_SETTABLE + STEP] = {ALU_PASS,   ALUOPTYPE_NORMAL, DEST_TEMP_REG_B,    1'h0, SOURCE_REGK_C,    SOURCE_ZERO, PC_ADVANCE, 2'h0};
        
        rom_array[OP_SETI]            = {ALU_PASS,   ALUOPTYPE_NORMAL, DEST_TEMPTABLE,     1'h1, SOURCE_REG_A,     SOURCE_ZERO, PC_IDLE,    2'h0};
        rom_array[OP_SETI + STEP]     = {ALU_PASS,   ALUOPTYPE_NORMAL, DEST_TEMP_B,        1'h0, SOURCE_REGK_C,    SOURCE_ZERO, PC_ADVANCE, 2'h0};
        
        rom_array[OP_SETFIELD]        = {ALU_PASS,   ALUOPTYPE_NORMAL, DEST_TEMPTABLE,     1'h1, SOURCE_REG_A,     SOURCE_ZERO, PC_IDLE,    2'h0};
        rom_array[OP_SETFIELD + STEP] = {ALU_PASS,   ALUOPTYPE_NORMAL, DEST_TEMP_K_B,      1'h0, SOURCE_REGK_C,    SOURCE_ZERO, PC_ADVANCE, 2'h0};
        
        rom_array[OP_NEWTABLE]        = {ALU_PASS,   ALUOPTYPE_NORMAL, DEST_REG_A,         1'h0, SOURCE_NEWTABLE,  SOURCE_ZERO, PC_ADVANCE, 2'h0};
        
        rom_array[OP_SELF]            = {ALU_PASS,   ALUOPTYPE_NORMAL, DEST_REG_A_PLUS_1,  1'h1, SOURCE_REG_B,     SOURCE_ZERO,   PC_IDLE,    2'h0};
        rom_array[OP_SELF + STEP]     = {ALU_PASS,   ALUOPTYPE_NORMAL, DEST_TEMPTABLE,     1'h0, SOURCE_REG_B,     SOURCE_ZERO,   PC_IDLE,    2'h0};
        rom_array[OP_SELF + 2 *STEP]  = {ALU_PASS,   ALUOPTYPE_NORMAL, DEST_REG_A,         1'h0, SOURCE_TEMP_REGK_C, SOURCE_ZERO, PC_ADVANCE, 2'h0};
        
        rom_array[OP_ADDI]            = {ALU_ADD,    ALUOPTYPE_NORMAL, DEST_REG_A,         1'h0, SOURCE_REG_B,     SOURCE_SC,     PC_ADVANCE,  2'h0};
        rom_array[OP_ADDK]            = {ALU_ADD,    ALUOPTYPE_NORMAL, DEST_REG_A,         1'h0, SOURCE_REG_B,     SOURCE_K_C,    PC_ADVANCE,  2'h0};
        rom_array[OP_SUBK]            = {ALU_SUB,    ALUOPTYPE_NORMAL, DEST_REG_A,         1'h0, SOURCE_REG_B,     SOURCE_K_C,    PC_ADVANCE,  2'h0};
        rom_array[OP_MULK]            = {ALU_MUL,    ALUOPTYPE_NORMAL, DEST_REG_A,         1'h0, SOURCE_REG_B,     SOURCE_K_C,    PC_ADVANCE,  2'h0};
        rom_array[OP_MODK]            = {ALU_MOD,    ALUOPTYPE_NORMAL, DEST_REG_A,         1'h0, SOURCE_REG_B,     SOURCE_K_C,    PC_ADVANCE,  2'h0};
        rom_array[OP_POWK]            = {ALU_POW,    ALUOPTYPE_NORMAL, DEST_REG_A,         1'h0, SOURCE_REG_B,     SOURCE_K_C,    PC_ADVANCE,  2'h0};
        rom_array[OP_DIVK]            = {ALU_DIV,    ALUOPTYPE_NORMAL, DEST_REG_A,         1'h0, SOURCE_REG_B,     SOURCE_K_C,    PC_ADVANCE,  2'h0};
        rom_array[OP_IDIVK]           = {ALU_IDIV,   ALUOPTYPE_NORMAL, DEST_REG_A,         1'h0, SOURCE_REG_B,     SOURCE_K_C,    PC_ADVANCE,  2'h0};
        rom_array[OP_BANDK]           = {ALU_AND,    ALUOPTYPE_BINARY, DEST_REG_A,         1'h0, SOURCE_REG_B,     SOURCE_K_C,    PC_ADVANCE,  2'h0};
        rom_array[OP_BORK]            = {ALU_OR,     ALUOPTYPE_BINARY, DEST_REG_A,         1'h0, SOURCE_REG_B,     SOURCE_K_C,    PC_ADVANCE,  2'h0};
        rom_array[OP_BXORK]           = {ALU_XOR,    ALUOPTYPE_BINARY, DEST_REG_A,         1'h0, SOURCE_REG_B,     SOURCE_K_C,    PC_ADVANCE,  2'h0};
        rom_array[OP_SHRI]            = {ALU_SHR,    ALUOPTYPE_NORMAL, DEST_REG_A,         1'h0, SOURCE_REG_B,     SOURCE_REGK_C, PC_ADVANCE,  2'h0};
        rom_array[OP_SHLI]            = {ALU_SHL,    ALUOPTYPE_NORMAL, DEST_REG_A,         1'h0, SOURCE_REG_B,     SOURCE_REGK_C, PC_ADVANCE,  2'h0};
        rom_array[OP_ADD]             = {ALU_ADD,    ALUOPTYPE_NORMAL, DEST_REG_A,         1'h0, SOURCE_REG_B,     SOURCE_REGK_C, PC_ADVANCE,  2'h0};
        rom_array[OP_SUB]             = {ALU_SUB,    ALUOPTYPE_NORMAL, DEST_REG_A,         1'h0, SOURCE_REG_B,     SOURCE_REGK_C, PC_ADVANCE,  2'h0};
        rom_array[OP_MUL]             = {ALU_MUL,    ALUOPTYPE_NORMAL, DEST_REG_A,         1'h0, SOURCE_REG_B,     SOURCE_REGK_C, PC_ADVANCE,  2'h0};
        rom_array[OP_MOD]             = {ALU_MOD,    ALUOPTYPE_NORMAL, DEST_REG_A,         1'h0, SOURCE_REG_B,     SOURCE_REGK_C, PC_ADVANCE,  2'h0};
        rom_array[OP_POW]             = {ALU_POW,    ALUOPTYPE_NORMAL, DEST_REG_A,         1'h0, SOURCE_REG_B,     SOURCE_REGK_C, PC_ADVANCE,  2'h0};
        rom_array[OP_DIV]             = {ALU_DIV,    ALUOPTYPE_NORMAL, DEST_REG_A,         1'h0, SOURCE_REG_B,     SOURCE_REGK_C, PC_ADVANCE,  2'h0};
        rom_array[OP_IDIV]            = {ALU_IDIV,   ALUOPTYPE_NORMAL, DEST_REG_A,         1'h0, SOURCE_REG_B,     SOURCE_REGK_C, PC_ADVANCE,  2'h0};
        rom_array[OP_BAND]            = {ALU_AND,    ALUOPTYPE_BINARY, DEST_REG_A,         1'h0, SOURCE_REG_B,     SOURCE_REGK_C, PC_ADVANCE,  2'h0};
        rom_array[OP_BOR]             = {ALU_OR,     ALUOPTYPE_BINARY, DEST_REG_A,         1'h0, SOURCE_REG_B,     SOURCE_REGK_C, PC_ADVANCE,  2'h0};
        rom_array[OP_BXOR]            = {ALU_XOR,    ALUOPTYPE_BINARY, DEST_REG_A,         1'h0, SOURCE_REG_B,     SOURCE_REGK_C, PC_ADVANCE,  2'h0};
        rom_array[OP_SHL]             = {ALU_SHL,    ALUOPTYPE_NORMAL, DEST_REG_A,         1'h0, SOURCE_REG_B,     SOURCE_REGK_C, PC_ADVANCE,  2'h0};
        rom_array[OP_SHR]             = {ALU_SHR,    ALUOPTYPE_NORMAL, DEST_REG_A,         1'h0, SOURCE_REG_B,     SOURCE_REGK_C, PC_ADVANCE,  2'h0};
        rom_array[OP_MMBIN]           = {ALU_PASS,   ALUOPTYPE_NORMAL, DEST_NONE,          1'h0, SOURCE_REG_A,     SOURCE_REG_B, 3'h0,         2'h0};
        rom_array[OP_MMBINI]          = {ALU_PASS,   ALUOPTYPE_NORMAL, DEST_NONE,          1'h0, SOURCE_REG_A,     SOURCE_REG_B, 3'h0,         2'h0};
        
        rom_array[OP_MMBINK]          = {ALU_PASS,   ALUOPTYPE_NORMAL, DEST_NONE,          1'h1, SOURCE_REG_A,     SOURCE_REG_B, PC_IDLE,      2'h0};
        rom_array[OP_MMBINK + STEP]   = {ALU_PASS,   ALUOPTYPE_NORMAL, DEST_NONE,          1'h0, SOURCE_REG_A,     SOURCE_REG_B, 3'h0,         2'h0};
        
        rom_array[OP_UNM]             = {ALU_SUB,    ALUOPTYPE_NORMAL, DEST_REG_A,         1'h0, SOURCE_ZERO,      SOURCE_REG_B, PC_ADVANCE,   2'h0};
        rom_array[OP_BNOT]            = {ALU_NOT,    ALUOPTYPE_BINARY, DEST_REG_A,         1'h0, SOURCE_REG_B,     SOURCE_ZERO,  PC_ADVANCE,   2'h0};
        rom_array[OP_NOT]             = {ALU_NOT,    ALUOPTYPE_LOGIC,  DEST_REG_A,         1'h0, SOURCE_REG_B,     SOURCE_ZERO,  PC_ADVANCE,   2'h0};
        rom_array[OP_LEN]             = {ALU_LEN,    ALUOPTYPE_NORMAL, DEST_REG_A,         1'h0, SOURCE_REG_B,     SOURCE_ZERO,  PC_ADVANCE,   2'h0};
        rom_array[OP_CONCAT]          = {ALU_CONCAT, ALUOPTYPE_NORMAL, DEST_REG_A,         1'h0, SOURCE_REG_A,     4'h0,         PC_ADVANCE,   2'h0};
        rom_array[OP_CLOSE]           = {ALU_PASS,   ALUOPTYPE_NORMAL, DEST_NONE,          1'h0, 4'h0,             4'h0,         PC_ADVANCE,   2'h0};
        rom_array[OP_TBC]             = {ALU_PASS,   ALUOPTYPE_NORMAL, DEST_NONE,          1'h0, 4'h0,             4'h0,         PC_ADVANCE,   2'h0};
        rom_array[OP_JMP]             = {ALU_ADD,    ALUOPTYPE_NORMAL, DEST_PC,            1'h0, SOURCE_PC,        SOURCE_SAX,   PC_SET,       2'h0};
        rom_array[OP_EQ]              = {ALU_CMP_EQ, ALUOPTYPE_NORMAL, DEST_NONE,          1'h0, SOURCE_REG_A,     SOURCE_REG_B, PC_COND_SKIP, 2'h0};
        rom_array[OP_LT]              = {ALU_CMP_LT, ALUOPTYPE_NORMAL, DEST_NONE,          1'h0, SOURCE_REG_A,     SOURCE_REG_B, PC_COND_SKIP, 2'h0};
        rom_array[OP_LE]              = {ALU_CMP_LE, ALUOPTYPE_NORMAL, DEST_NONE,          1'h0, SOURCE_REG_A,     SOURCE_REG_B, PC_COND_SKIP, 2'h0};
        rom_array[OP_EQK]             = {ALU_CMP_EQ, ALUOPTYPE_NORMAL, DEST_NONE,          1'h0, SOURCE_REG_A,     SOURCE_K_B,   PC_COND_SKIP, 2'h0};
        rom_array[OP_EQI]             = {ALU_CMP_EQ, ALUOPTYPE_NORMAL, DEST_NONE,          1'h0, SOURCE_REG_A,     SOURCE_REG_B, PC_COND_SKIP, 2'h0};
        rom_array[OP_LTI]             = {ALU_CMP_LT, ALUOPTYPE_NORMAL, DEST_NONE,          1'h0, SOURCE_REG_A,     SOURCE_REG_B, PC_COND_SKIP, 2'h0};
        rom_array[OP_LEI]             = {ALU_CMP_LE, ALUOPTYPE_NORMAL, DEST_NONE,          1'h0, SOURCE_REG_A,     SOURCE_REG_B, PC_COND_SKIP, 2'h0};
        rom_array[OP_GTI]             = {ALU_CMP_GT, ALUOPTYPE_NORMAL, DEST_NONE,          1'h0, SOURCE_REG_A,     SOURCE_REG_B, PC_COND_SKIP, 2'h0};
        rom_array[OP_GEI]             = {ALU_CMP_GE, ALUOPTYPE_NORMAL, DEST_NONE,          1'h0, SOURCE_REG_A,     SOURCE_REG_B, PC_COND_SKIP, 2'h0};
        rom_array[OP_TEST]            = {ALU_TEST,   ALUOPTYPE_NORMAL, DEST_NONE,          1'h0, SOURCE_REG_A,     SOURCE_ZERO,  PC_COND_SKIP, 2'h0};
        rom_array[OP_TESTSET]         = {ALU_TEST,   ALUOPTYPE_NORMAL, DEST_NONE,          1'h0, SOURCE_REG_A,     SOURCE_ZERO,  PC_COND_SKIP, 2'h0};
        
        rom_array[OP_CALL]            = {ALU_PASS,   ALUOPTYPE_NORMAL, DEST_NONE,          1'h1, 4'h2,             4'h0,         3'h0,         2'h0};
        rom_array[OP_CALL + STEP]     = {ALU_PASS,   ALUOPTYPE_NORMAL, DEST_NONE,          1'h0, 4'h0,             4'h0,         3'h0,         2'h0};
        
        rom_array[OP_TAILCALL]        = {ALU_PASS,   ALUOPTYPE_NORMAL, DEST_NONE,          1'h1, 4'h2,             4'h0,         3'h0,         2'h0};
        rom_array[OP_TAILCALL + STEP] = {ALU_PASS,   ALUOPTYPE_NORMAL, DEST_NONE,          1'h0, 4'h0,             4'h0,         3'h0,         2'h0};
        
        rom_array[OP_RETURN]          = {ALU_PASS,   ALUOPTYPE_NORMAL, DEST_NONE,          1'h1, 4'h2,             4'h0,         PC_IDLE,      2'h0};
        rom_array[OP_RETURN + STEP]   = {ALU_PASS,   ALUOPTYPE_NORMAL, DEST_NONE,          1'h0, 4'h0,             4'h0,         PC_RETURN,    2'h0};
        
        rom_array[OP_RETURN0]         = {ALU_PASS,   ALUOPTYPE_NORMAL, DEST_NONE,          1'h0, SOURCE_ZERO,      SOURCE_ZERO,  PC_RETURN,    2'h0};
        rom_array[OP_RETURN1]         = {ALU_PASS,   ALUOPTYPE_NORMAL, DEST_REG_A,         1'h0, SOURCE_REG_A,     SOURCE_ZERO,  PC_RETURN,    2'h0};
        rom_array[OP_FORLOOP]         = {ALU_FORLOOP,ALUOPTYPE_NORMAL, DEST_NONE,          1'h1, SOURCE_ZERO,      SOURCE_ZERO,  3'h2,         2'h0};
        rom_array[OP_FORPREP]         = {5'h13,      ALUOPTYPE_NORMAL, DEST_NONE,          1'h1, SOURCE_ZERO,      SOURCE_ZERO,  3'h1,         2'h0};
        rom_array[OP_TFORPREP]        = {ALU_PASS,   ALUOPTYPE_NORMAL, DEST_NONE,          1'h1, SOURCE_ZERO,      SOURCE_ZERO,  3'h1,         2'h0};
        rom_array[OP_TFORCALL]        = {ALU_PASS,   ALUOPTYPE_NORMAL, DEST_NONE,          1'h1, SOURCE_ZERO,      SOURCE_ZERO,  3'h0,         2'h0};
        rom_array[OP_TFORLOOP]        = {ALU_PASS,   ALUOPTYPE_NORMAL, DEST_NONE,          1'h2, SOURCE_ZERO,      SOURCE_ZERO,  3'h2,         2'h0};
        
        rom_array[OP_SETLIST]         = {ALU_PASS,   ALUOPTYPE_NORMAL, DEST_NONE,          1'h1, SOURCE_ZERO,      SOURCE_ZERO,  PC_IDLE,      2'h0};
        rom_array[OP_SETLIST + STEP]  = {ALU_PASS,   ALUOPTYPE_NORMAL, DEST_NONE,          1'h0, SOURCE_ZERO,      SOURCE_ZERO,  PC_ADVANCE,   2'h0};
        
        rom_array[OP_CLOSURE]         = {ALU_PASS,   ALUOPTYPE_NORMAL, DEST_NONE,          1'h1, SOURCE_ZERO,      SOURCE_ZERO,  PC_IDLE,      2'h0};
        rom_array[OP_CLOSURE + STEP]  = {ALU_PASS,   ALUOPTYPE_NORMAL, DEST_NONE,          1'h0, SOURCE_ZERO,      SOURCE_ZERO,  PC_ADVANCE,   2'h0};
        
        rom_array[OP_VARARG]          = {ALU_PASS,   ALUOPTYPE_NORMAL, DEST_NONE,          1'h1, SOURCE_ZERO,      SOURCE_ZERO,  3'h0,         2'h0};
        rom_array[OP_VARARGPREP]      = {ALU_PASS,   ALUOPTYPE_NORMAL, DEST_NONE,          1'h0, SOURCE_ZERO,      SOURCE_ZERO,  3'h0,         2'h1};
        rom_array[OP_EXTRAARG]        = {ALU_PASS,   ALUOPTYPE_NORMAL, DEST_NONE,          1'h0, SOURCE_ZERO,      SOURCE_ZERO,  3'h0,         2'h0};
    end

    assign {alu_op, alu_optype, dest, next_microop, operand_a_sel, operand_b_sel, pc_op, stack_op} = rom_array[{step, opcode}];

/* verilator lint_on WIDTHEXPAND */
endmodule
