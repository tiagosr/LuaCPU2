### 🧪 Test Results
- 3 passing tests (reset behavior verification, integrated CPU simulation, OP_MOVE/OP_LOADI/OP_LOADK execution with 1 passing register write)

### ✅ Completed
- Specification written at [SPEC.md](docs/SPEC.md)
- CPU module scaffolding with clock, reset, external memory bus interface, UART interface, error/halt signals, and parameter definitions
- Verilator test suite with testbench, external memory model, UART model, and Makefile
- CPU top-level module scaffolding at [src/rtl/cpu.sv](src/rtl/cpu.sv) with all parameters, I/O interfaces, and submodule placeholders
- Register write-thru cache module at [src/rtl/reg_cache.sv](src/rtl/reg_cache.sv) with 32-entry LRU cache, write-thru bus forwarding, cache miss stall handling, and window invalidation
- Stack pointer and window base manager module at [src/rtl/stack_ptr.sv](src/rtl/stack_ptr.sv) with stack push/pop, WB advance/retreat/set operations, overflow detection, and top marker tracking
- Microcode ROM at [src/rtl/microcode_rom.sv](src/rtl/microcode_rom.sv) with 1024×64-bit entries covering all Lua 5.4 opcodes, reorganized with DONE_OFFSET for multi-step operations
- Microcode sequencer at [src/rtl/microcode_seq.sv](src/rtl/microcode_seq.sv) with variable-length sequence support, branching, DONE_OFFSET continuation, and immediate operand decoding
- Instruction ROM at [src/rtl/instr_rom.sv](src/rtl/instr_rom.sv) for on-chip bytecode storage
- Full CPU integration with register cache, microcode sequencer, stack pointer, and instruction ROM wired together
- ALU datapath module at [src/rtl/alu.sv](src/rtl/alu.sv) with NaN-boxed integer/double arithmetic, bitwise operations, comparisons, and type detection
- Value converter module at [src/rtl/value_conv.sv](src/rtl/value_conv.sv) for NaN-boxing immediate values and k-table data
- OP_MOVE, OP_LOADI, OP_LOADK microcode sequences with two-step execution (read then write)
- Testbench with bytecode preload and register value verification