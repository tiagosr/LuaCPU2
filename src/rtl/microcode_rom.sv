`include "microcode_mnemonics.vh"
`include "opcode_mnemonics.vh"

module microcode_rom #(
    parameter ROM_DEPTH = 512
)(
    input  wire clk,
    input  wire [6:0] opcode,
    input  wire [1:0] step,
    output wire [63:0] data
);

    localparam STEP = 128;

    reg [29:0] rom_array [0:ROM_DEPTH-1];

    initial begin
        for (integer i = 0; i < ROM_DEPTH; i = i + 1) begin
            rom_array[i] = {ALU_PASS, 4'h0, 4'h0, 4'h0, 3'h0, 3'h0, 2'h1, 2'h0, 2'h0, 1'h0}; // MC_NOP;
        end

        rom_array[OP_MOVE]            = {ALU_PASS,      4'h0, 4'h1, 4'h0, 3'h0, 3'h0, 2'h0, 2'h0, 2'h0, 1'h1};
        rom_array[OP_MOVE + STEP]     = {ALU_PASS,      4'h0, 4'h0, 4'h1, 3'h0, 3'h0, 2'h1, 2'h0, 2'h0, 1'h1};
        rom_array[OP_LOADI]           = {ALU_PASS,      4'h0, 4'h0, 4'h0, 3'h0, 3'h0, 2'h1, 2'h0, 2'h0, 1'h1};
        rom_array[OP_LOADF]           = {ALU_PASS,      4'h0, 4'h0, 4'h0, 3'h0, 3'h0, 2'h1, 2'h0, 2'h0, 1'h1};
        rom_array[OP_LOADK]           = {ALU_PASS,      4'h0, 4'h0, 4'h0, 3'h1, 3'h0, 2'h0, 2'h0, 2'h0, 1'h1};
        rom_array[OP_LOADK + STEP]    = {ALU_PASS,      4'h0, 4'h0, 4'h0, 3'h1, 3'h0, 2'h1, 2'h0, 2'h0, 1'h1};
        rom_array[OP_LOADKX]          = {ALU_PASS,      4'h0, 4'h0, 4'h3, 3'h1, 3'h0, 2'h0, 2'h0, 2'h0, 1'h1};
        rom_array[OP_LOADKX + STEP]   = {ALU_PASS,      4'h0, 4'h0, 4'h0, 3'h0, 3'h0, 2'h1, 2'h0, 2'h0, 1'h1};
        rom_array[OP_LOADTRUE]        = {ALU_LOADTRUE,  4'h0, 4'h0, 4'h0, 3'h0, 3'h0, 2'h1, 2'h0, 2'h0, 1'h1};
        rom_array[OP_LOADFALSE]       = {ALU_LOADFALSE, 4'h0, 4'h0, 4'h0, 3'h0, 3'h0, 2'h1, 2'h0, 2'h0, 1'h1};
        rom_array[OP_LFALSESKIP]      = {ALU_LOADFALSE, 4'h0, 4'h0, 4'h0, 3'h0, 3'h1, 2'h1, 2'h0, 2'h0, 1'h1};
        rom_array[OP_LOADNIL]         = {ALU_LOADNIL,   4'h0, 4'h0, 4'h0, 3'h0, 3'h0, 2'h1, 2'h0, 2'h0, 1'h1};
        rom_array[OP_GETUPVAL]        = {ALU_PASS,      4'h0, 4'h1, 4'h0, 3'h4, 3'h0, 2'h0, 2'h0, 2'h0, 1'h1};
        rom_array[OP_GETUPVAL + STEP] = {ALU_PASS,      4'h0, 4'h0, 4'h0, 3'h0, 3'h0, 2'h1, 2'h0, 2'h0, 1'h1};
        rom_array[OP_SETUPVAL]        = {ALU_PASS,      4'h0, 4'h1, 4'h0, 3'h5, 3'h0, 2'h0, 2'h0, 2'h0, 1'h1};
        rom_array[OP_SETUPVAL + STEP] = {ALU_PASS,      4'h0, 4'h0, 4'h0, 3'h0, 3'h0, 2'h1, 2'h0, 2'h0, 1'h1};
        rom_array[OP_GETTABUP]        = {ALU_PASS,      4'h0, 4'h1, 4'h3, 3'h4, 3'h0, 2'h0, 2'h0, 2'h0, 1'h1};
        rom_array[OP_GETTABUP + STEP] = {ALU_PASS,      4'h0, 4'h0, 4'h0, 3'h0, 3'h0, 2'h1, 2'h0, 2'h0, 1'h1};
        rom_array[OP_GETTABLE]        = {ALU_PASS,      4'h0, 4'h1, 4'h2, 3'h0, 3'h0, 2'h0, 2'h0, 2'h0, 1'h1};
        rom_array[OP_GETTABLE + STEP] = {ALU_PASS,      4'h0, 4'h0, 4'h0, 3'h0, 3'h0, 2'h1, 2'h0, 2'h0, 1'h1};
        rom_array[OP_GETI]            = {ALU_PASS,      4'h0, 4'h1, 4'h2, 3'h0, 3'h0, 2'h0, 2'h0, 2'h0, 1'h1};
        rom_array[OP_GETI + STEP]     = {ALU_PASS,      4'h0, 4'h0, 4'h0, 3'h0, 3'h0, 2'h1, 2'h0, 2'h0, 1'h1};
        rom_array[OP_GETFIELD]        = {ALU_PASS,      4'h0, 4'h1, 4'h3, 3'h1, 3'h0, 2'h0, 2'h0, 2'h0, 1'h1};
        rom_array[OP_GETFIELD + STEP] = {ALU_PASS,      4'h0, 4'h0, 4'h0, 3'h0, 3'h0, 2'h1, 2'h0, 2'h0, 1'h1};
        rom_array[OP_SETTABUP]        = {ALU_PASS,      4'h0, 4'h1, 4'h3, 3'h4, 3'h0, 2'h0, 2'h0, 2'h0, 1'h1};
        rom_array[OP_SETTABUP + STEP] = {ALU_PASS,      4'h0, 4'h0, 4'h0, 3'h0, 3'h0, 2'h1, 2'h0, 2'h0, 1'h1};
        rom_array[OP_SETTABLE]        = {ALU_PASS,      4'h0, 4'h1, 4'h2, 3'h0, 3'h0, 2'h0, 2'h0, 2'h0, 1'h1};
        rom_array[OP_SETTABLE + STEP] = {ALU_PASS,      4'h0, 4'h0, 4'h0, 3'h0, 3'h0, 2'h1, 2'h0, 2'h0, 1'h1};
        rom_array[OP_SETI]            = {ALU_PASS,      4'h0, 4'h1, 4'h2, 3'h0, 3'h0, 2'h0, 2'h0, 2'h0, 1'h1};
        rom_array[OP_SETI + STEP]     = {ALU_PASS,      4'h0, 4'h0, 4'h0, 3'h0, 3'h0, 2'h1, 2'h0, 2'h0, 1'h1};
        rom_array[OP_SETFIELD]        = {ALU_PASS,      4'h0, 4'h1, 4'h3, 3'h1, 3'h0, 2'h0, 2'h0, 2'h0, 1'h1};
        rom_array[OP_SETFIELD + STEP] = {ALU_PASS,      4'h0, 4'h0, 4'h0, 3'h0, 3'h0, 2'h1, 2'h0, 2'h0, 1'h1};
        rom_array[OP_NEWTABLE]        = {ALU_PASS,      4'h0, 4'h0, 4'h0, 3'h3, 3'h0, 2'h0, 2'h0, 2'h0, 1'h1};
        rom_array[OP_NEWTABLE + STEP] = {ALU_PASS,      4'h0, 4'h0, 4'h0, 3'h0, 3'h0, 2'h1, 2'h0, 2'h0, 1'h1};
        rom_array[OP_SELF]            = {ALU_PASS,      4'h0, 4'h1, 4'h2, 3'h0, 3'h0, 2'h0, 2'h0, 2'h0, 1'h1};
        rom_array[OP_SELF + STEP]     = {ALU_PASS,      4'h0, 4'h0, 4'h0, 3'h0, 3'h0, 2'h1, 2'h0, 2'h0, 1'h1};
        rom_array[OP_ADDI]            = {ALU_ADD,       4'h0, 4'h1, 4'h0, 3'h0, 3'h0, 2'h1, 2'h0, 2'h0, 1'h1};
        rom_array[OP_ADDK]            = {ALU_PASS,      4'h0, 4'h0, 4'h3, 3'h1, 3'h0, 2'h0, 2'h0, 2'h0, 1'h1};
        rom_array[OP_ADDK + STEP]     = {ALU_PASS,      4'h0, 4'h1, 4'h3, 3'h0, 3'h0, 2'h0, 2'h0, 2'h0, 1'h1};
        rom_array[OP_ADDK + 2 * STEP] = {ALU_ADD,       4'h0, 4'h1, 4'h3, 3'h0, 3'h0, 2'h1, 2'h0, 2'h0, 1'h1};
        rom_array[OP_SUBK]            = {ALU_PASS,      4'h0, 4'h0, 4'h3, 3'h1, 3'h0, 2'h0, 2'h0, 2'h0, 1'h1};
        rom_array[OP_SUBK + STEP]     = {ALU_PASS,      4'h0, 4'h1, 4'h3, 3'h0, 3'h0, 2'h0, 2'h0, 2'h0, 1'h1};
        rom_array[OP_SUBK + 2 * STEP] = {ALU_SUB,       4'h0, 4'h1, 4'h3, 3'h0, 3'h0, 2'h1, 2'h0, 2'h0, 1'h1};
        rom_array[OP_MULK]            = {ALU_PASS,      4'h0, 4'h0, 4'h3, 3'h1, 3'h0, 2'h0, 2'h0, 2'h0, 1'h1};
        rom_array[OP_MULK + STEP]     = {ALU_PASS,      4'h0, 4'h1, 4'h3, 3'h0, 3'h0, 2'h0, 2'h0, 2'h0, 1'h1};
        rom_array[OP_MULK + 2 * STEP] = {ALU_MUL,       4'h0, 4'h1, 4'h3, 3'h0, 3'h0, 2'h1, 2'h0, 2'h0, 1'h1};
        rom_array[OP_MODK]            = {ALU_MOD,       4'h0, 4'h1, 4'h3, 3'h1, 3'h0, 2'h0, 2'h0, 2'h0, 1'h1};
        rom_array[OP_MODK + STEP]     = {ALU_MOD,       4'h0, 4'h1, 4'h3, 3'h0, 3'h0, 2'h1, 2'h0, 2'h0, 1'h1};
        rom_array[OP_POWK]            = {ALU_POW,       4'h0, 4'h1, 4'h3, 3'h1, 3'h0, 2'h0, 2'h0, 2'h0, 1'h1};
        rom_array[OP_POWK + STEP]     = {ALU_POW,       4'h0, 4'h1, 4'h3, 3'h0, 3'h0, 2'h1, 2'h0, 2'h0, 1'h1};
        rom_array[OP_DIVK]            = {ALU_DIV,       4'h0, 4'h1, 4'h3, 3'h1, 3'h0, 2'h0, 2'h0, 2'h0, 1'h1};
        rom_array[OP_DIVK + STEP]     = {ALU_DIV,       4'h0, 4'h1, 4'h3, 3'h0, 3'h0, 2'h1, 2'h0, 2'h0, 1'h1};
        rom_array[OP_IDIVK]           = {ALU_IDIV,      4'h0, 4'h1, 4'h3, 3'h1, 3'h0, 2'h0, 2'h0, 2'h0, 1'h1};
        rom_array[OP_IDIVK + STEP]    = {ALU_IDIV,      4'h0, 4'h1, 4'h3, 3'h0, 3'h0, 2'h1, 2'h0, 2'h0, 1'h1};
        rom_array[OP_BANDK]           = {ALU_BAND,      4'h0, 4'h1, 4'h3, 3'h1, 3'h0, 2'h0, 2'h0, 2'h0, 1'h1};
        rom_array[OP_BANDK + STEP]    = {ALU_BAND,      4'h0, 4'h1, 4'h3, 3'h0, 3'h0, 2'h1, 2'h0, 2'h0, 1'h1};
        rom_array[OP_BORK]            = {ALU_BOR,       4'h0, 4'h1, 4'h3, 3'h1, 3'h0, 2'h0, 2'h0, 2'h0, 1'h1};
        rom_array[OP_BORK + STEP]     = {ALU_BOR,       4'h0, 4'h1, 4'h3, 3'h0, 3'h0, 2'h1, 2'h0, 2'h0, 1'h1};
        rom_array[OP_BXORK]           = {ALU_BXOR,      4'h0, 4'h1, 4'h3, 3'h1, 3'h0, 2'h0, 2'h0, 2'h0, 1'h1};
        rom_array[OP_BXORK + STEP]    = {ALU_BXOR,      4'h0, 4'h1, 4'h3, 3'h0, 3'h0, 2'h1, 2'h0, 2'h0, 1'h1};
        rom_array[OP_SHRI]            = {ALU_SHR,       4'h0, 4'h1, 4'h0, 3'h0, 3'h0, 2'h1, 2'h0, 2'h0, 1'h1};
        rom_array[OP_SHLI]            = {ALU_SHL,       4'h0, 4'h1, 4'h0, 3'h0, 3'h0, 2'h1, 2'h0, 2'h0, 1'h1};
        rom_array[OP_ADD]             = {ALU_ADD,       4'h0, 4'h1, 4'h2, 3'h0, 3'h0, 2'h1, 2'h0, 2'h0, 1'h1};
        rom_array[OP_ADD + STEP]      = {ALU_PASS,      4'h0, 4'h1, 4'h2, 3'h0, 3'h0, 2'h0, 2'h0, 2'h0, 1'h1};
        rom_array[OP_ADD + 2 * STEP]  = {ALU_ADD,       4'h0, 4'h0, 4'h2, 3'h0, 3'h0, 2'h1, 2'h0, 2'h0, 1'h1};
        rom_array[OP_SUB]             = {ALU_SUB,       4'h0, 4'h1, 4'h2, 3'h0, 3'h0, 2'h1, 2'h0, 2'h0, 1'h1};
        rom_array[OP_SUB + STEP]      = {ALU_PASS,      4'h0, 4'h1, 4'h2, 3'h0, 3'h0, 2'h0, 2'h0, 2'h0, 1'h1};
        rom_array[OP_SUB + 2 * STEP]  = {ALU_SUB,       4'h0, 4'h0, 4'h2, 3'h0, 3'h0, 2'h1, 2'h0, 2'h0, 1'h1};
        rom_array[OP_MUL]             = {ALU_MUL,       4'h0, 4'h1, 4'h2, 3'h0, 3'h0, 2'h1, 2'h0, 2'h0, 1'h1};
        rom_array[OP_MUL + STEP]      = {ALU_PASS,      4'h0, 4'h1, 4'h2, 3'h0, 3'h0, 2'h0, 2'h0, 2'h0, 1'h1};
        rom_array[OP_MUL + 2 * STEP]  = {ALU_MUL,       4'h0, 4'h0, 4'h2, 3'h0, 3'h0, 2'h1, 2'h0, 2'h0, 1'h1};
        rom_array[OP_MOD]             = {ALU_MOD,       4'h0, 4'h1, 4'h2, 3'h0, 3'h0, 2'h1, 2'h0, 2'h0, 1'h1};
        rom_array[OP_POW]             = {ALU_POW,       4'h0, 4'h1, 4'h2, 3'h0, 3'h0, 2'h1, 2'h0, 2'h0, 1'h1};
        rom_array[OP_DIV]             = {ALU_DIV,       4'h0, 4'h1, 4'h2, 3'h0, 3'h0, 2'h1, 2'h0, 2'h0, 1'h1};
        rom_array[OP_IDIV]            = {ALU_BAND,      4'h0, 4'h1, 4'h2, 3'h0, 3'h0, 2'h1, 2'h0, 2'h0, 1'h1};
        rom_array[OP_BAND]            = {ALU_BOR,       4'h0, 4'h1, 4'h2, 3'h0, 3'h0, 2'h1, 2'h0, 2'h0, 1'h1};
        rom_array[OP_BOR]             = {ALU_BXOR,      4'h0, 4'h1, 4'h2, 3'h0, 3'h0, 2'h1, 2'h0, 2'h0, 1'h1};
        rom_array[OP_BXOR]            = {ALU_SHL,       4'h0, 4'h1, 4'h2, 3'h0, 3'h0, 2'h1, 2'h0, 2'h0, 1'h1};
        rom_array[OP_SHL]             = {ALU_SHR,       4'h0, 4'h1, 4'h2, 3'h0, 3'h0, 2'h1, 2'h0, 2'h0, 1'h1};
        rom_array[OP_SHR]             = {ALU_IDIV,      4'h0, 4'h1, 4'h2, 3'h0, 3'h0, 2'h1, 2'h0, 2'h0, 1'h1};
        rom_array[OP_MMBIN]           = {ALU_PASS,      4'h0, 4'h1, 4'h2, 3'h0, 3'h0, 2'h1, 2'h0, 2'h0, 1'h1};
        rom_array[OP_MMBINI]          = {ALU_PASS,      4'h0, 4'h1, 4'h0, 3'h0, 3'h0, 2'h1, 2'h0, 2'h0, 1'h1};
        rom_array[OP_MMBINK]          = {ALU_PASS,      4'h0, 4'h1, 4'h3, 3'h1, 3'h0, 2'h0, 2'h0, 2'h0, 1'h1};
        rom_array[OP_MMBINK + STEP]   = {ALU_PASS,      4'h0, 4'h1, 4'h3, 3'h0, 3'h0, 2'h1, 2'h0, 2'h0, 1'h1};
        rom_array[OP_UNM]             = {ALU_UNM,       4'h0, 4'h1, 4'h0, 3'h0, 3'h0, 2'h1, 2'h0, 2'h0, 1'h1};
        rom_array[OP_BNOT]            = {ALU_BNOT,      4'h0, 4'h1, 4'h0, 3'h0, 3'h0, 2'h1, 2'h0, 2'h0, 1'h1};
        rom_array[OP_NOT]             = {ALU_NOT,       4'h0, 4'h1, 4'h0, 3'h0, 3'h0, 2'h1, 2'h0, 2'h0, 1'h1};
        rom_array[OP_LEN]             = {ALU_LEN,       4'h0, 4'h1, 4'h0, 3'h0, 3'h0, 2'h1, 2'h0, 2'h0, 1'h1};
        rom_array[OP_CONCAT]          = {ALU_CONCAT,    4'h0, 4'h1, 4'h0, 3'h0, 3'h0, 2'h1, 2'h0, 2'h0, 1'h1};
        rom_array[OP_CLOSE]           = {ALU_PASS,      4'h0, 4'h1, 4'h0, 3'h0, 3'h0, 2'h1, 2'h0, 2'h0, 1'h1};
        rom_array[OP_TBC]             = {ALU_PASS,      4'h0, 4'h1, 4'h0, 3'h0, 3'h0, 2'h1, 2'h0, 2'h0, 1'h1};
        rom_array[OP_JMP]             = {ALU_PASS,      4'h0, 4'h0, 4'h0, 3'h0, 3'h2, 2'h1, 2'h0, 2'h0, 1'h1};
        rom_array[OP_EQ]              = {ALU_CMP_EQ,    4'h0, 4'h1, 4'h2, 3'h0, 3'h0, 2'h2, 2'h0, 2'h0, 1'h1};
        rom_array[OP_LT]              = {ALU_CMP_LT,    4'h0, 4'h1, 4'h2, 3'h0, 3'h0, 2'h2, 2'h0, 2'h0, 1'h1};
        rom_array[OP_LE]              = {ALU_CMP_LE,    4'h0, 4'h1, 4'h2, 3'h0, 3'h0, 2'h2, 2'h0, 2'h0, 1'h1};
        rom_array[OP_EQK]             = {ALU_CMP_EQ,    4'h0, 4'h1, 4'h3, 3'h1, 3'h0, 2'h0, 2'h0, 2'h0, 1'h1};
        rom_array[OP_EQK + STEP]      = {ALU_CMP_EQ,    4'h0, 4'h1, 4'h3, 3'h0, 3'h0, 2'h2, 2'h0, 2'h0, 1'h1};
        rom_array[OP_EQI]             = {ALU_CMP_EQ,    4'h0, 4'h1, 4'h0, 3'h0, 3'h0, 2'h2, 2'h0, 2'h0, 1'h1};
        rom_array[OP_LTI]             = {ALU_CMP_LT,    4'h0, 4'h1, 4'h0, 3'h0, 3'h0, 2'h2, 2'h0, 2'h0, 1'h1};
        rom_array[OP_LEI]             = {ALU_CMP_LE,    4'h0, 4'h1, 4'h0, 3'h0, 3'h0, 2'h2, 2'h0, 2'h0, 1'h1};
        rom_array[OP_GTI]             = {ALU_CMP_GT,    4'h0, 4'h1, 4'h0, 3'h0, 3'h0, 2'h2, 2'h0, 2'h0, 1'h1};
        rom_array[OP_GEI]             = {ALU_CMP_GE,    4'h0, 4'h1, 4'h0, 3'h0, 3'h0, 2'h2, 2'h0, 2'h0, 1'h1};
        rom_array[OP_TEST]            = {ALU_TEST,      4'h0, 4'h1, 4'h0, 3'h0, 3'h0, 2'h2, 2'h0, 2'h0, 1'h1};
        rom_array[OP_TESTSET]         = {ALU_TEST,      4'h0, 4'h1, 4'h0, 3'h0, 3'h0, 2'h2, 2'h0, 2'h0, 1'h1};
        rom_array[OP_CALL]            = {ALU_PASS,      4'h0, 4'h1, 4'h2, 3'h0, 3'h0, 2'h0, 2'h0, 2'h0, 1'h1};
        rom_array[OP_CALL + STEP]     = {ALU_PASS,      4'h0, 4'h0, 4'h0, 3'h0, 3'h0, 2'h1, 2'h0, 2'h0, 1'h1};
        rom_array[OP_TAILCALL]        = {ALU_PASS,      4'h0, 4'h1, 4'h2, 3'h0, 3'h0, 2'h0, 2'h0, 2'h0, 1'h1};
        rom_array[OP_TAILCALL + STEP] = {ALU_PASS,      4'h0, 4'h0, 4'h0, 3'h0, 3'h0, 2'h1, 2'h0, 2'h0, 1'h1};
        rom_array[OP_RETURN]          = {ALU_PASS,      4'h0, 4'h1, 4'h2, 3'h0, 3'h0, 2'h0, 2'h0, 2'h0, 1'h1};
        rom_array[OP_RETURN + STEP]   = {ALU_PASS,      4'h0, 4'h0, 4'h0, 3'h0, 3'h0, 2'h1, 2'h0, 2'h0, 1'h1};
        rom_array[OP_RETURN0]         = {ALU_PASS,      4'h0, 4'h0, 4'h0, 3'h0, 3'h0, 2'h1, 2'h0, 2'h0, 1'h1};
        rom_array[OP_RETURN1]         = {ALU_PASS,      4'h0, 4'h0, 4'h0, 3'h0, 3'h0, 2'h1, 2'h0, 2'h0, 1'h1};
        rom_array[OP_FORLOOP]         = {ALU_FORLOOP,   4'h0, 4'h1, 4'h2, 3'h0, 3'h2, 2'h2, 2'h0, 2'h0, 1'h1};
        rom_array[OP_FORPREP]         = {5'h13,         4'h0, 4'h1, 4'h2, 3'h0, 3'h1, 2'h2, 2'h0, 2'h0, 1'h1};
        rom_array[OP_TFORPREP]        = {ALU_PASS,      4'h0, 4'h1, 4'h0, 3'h0, 3'h1, 2'h1, 2'h0, 2'h0, 1'h1};
        rom_array[OP_TFORCALL]        = {ALU_PASS,      4'h0, 4'h1, 4'h2, 3'h0, 3'h0, 2'h1, 2'h0, 2'h0, 1'h1};
        rom_array[OP_TFORLOOP]        = {ALU_PASS,      4'h0, 4'h2, 4'h0, 3'h0, 3'h2, 2'h2, 2'h0, 2'h0, 1'h1};
        rom_array[OP_SETLIST]         = {ALU_PASS,      4'h0, 4'h1, 4'h2, 3'h0, 3'h0, 2'h0, 2'h0, 2'h0, 1'h1};
        rom_array[OP_SETLIST + STEP]  = {ALU_PASS,      4'h0, 4'h0, 4'h0, 3'h0, 3'h0, 2'h1, 2'h0, 2'h0, 1'h1};
        rom_array[OP_CLOSURE]         = {ALU_PASS,      4'h0, 4'h1, 4'h0, 3'h2, 3'h0, 2'h0, 2'h0, 2'h0, 1'h1};
        rom_array[OP_CLOSURE + STEP]  = {ALU_PASS,      4'h0, 4'h0, 4'h0, 3'h0, 3'h0, 2'h1, 2'h0, 2'h0, 1'h1};
        rom_array[OP_VARARG]          = {ALU_PASS,      4'h0, 4'h1, 4'h2, 3'h0, 3'h0, 2'h1, 2'h0, 2'h0, 1'h1};
        rom_array[OP_VARARGPREP]      = {ALU_PASS,      4'h0, 4'h0, 4'h0, 3'h0, 3'h0, 2'h1, 2'h0, 2'h1, 1'h1};
        rom_array[OP_EXTRAARG]        = {ALU_PASS,      4'h0, 4'h0, 4'h0, 3'h0, 3'h0, 2'h1, 2'h0, 2'h0, 1'h1};
    end

    assign data = {rom_array[{step, opcode}], 34'h0};

endmodule
