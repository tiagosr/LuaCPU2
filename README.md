LuaCPU2
=======

Implementation of the Lua 5.4 bytecode VM in Verilog/SystemVerilog, particularly for use with a FPGA implementation of PICO-8. This is the project for the CPU on its own, not the entire PICO-8 implementation - that one is a separate project.

This, similar to [jsvcc80](https://github.com/tiagosr/jsvcc80/), is an LLM agent orchestration experiment "disguised" as a hardware synthesis project.

The intention is to learn what are the processes that avoid "agent orchestration rot", where the process of prompting an implementation starts giving way to the degradation of software planning and architecture decisions (both on the model's and on the user/prompter's side). The threshold for this phenomenon seems more manageable (on both mental and financial terms) in the current crop of LLMs that can be run in a local setup, on either a 48GB Macbook Pro M4 or a 128GB AMD "Strix Halo" Ryzen AI MAX+.

## Current Implementation Status

### ✅ Completed
See [CHANGELOG.md](CHANGELOG.md)

### 🔄 In Progress
- Writeback pipeline timing - writeback_pending set when microcode sequence completes but data validity signals (alu_result_valid, reg_cache_read_valid) are registered 1 cycle behind; bus writeback not triggering; PC stuck at 1
- Logic debugging: PC increment, bus request/assert timing, writeback commit flow

### 🔜 Next Steps
- Fix writeback pipeline to properly trigger bus writeback when data validity signals are available
- Fix bus_addr calculation (stack_ptr_wb offset incorrect)
- Verify OP_MOVE, OP_LOADI, OP_LOADK, OP_LOADTRUE, OP_LOADFALSE, OP_LOADNIL execute correctly
- Verify OP_ADD, OP_ADDK execute correctly with proper writeback timing
- Implement a DDR1 SDRAM controller
- Implement a test-only simulation of a DDR1 SDRAM

### 📔 Backlog
- Verilog lint/typecheck setup
