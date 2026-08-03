LuaCPU2
=======

Implementation of the Lua 5.4 bytecode VM in Verilog/SystemVerilog, particularly for use with a FPGA implementation of PICO-8. This is the project for the CPU on its own, not the entire PICO-8 implementation - that one is a separate project.

This, similar to [jsvcc80](https://github.com/tiagosr/jsvcc80/), is an LLM agent orchestration experiment "disguised" as a hardware synthesis project.

The intention is to learn what are the processes that avoid "agent orchestration rot", where the process of prompting an implementation starts giving way to the degradation of software planning and architecture decisions (both on the model's and on the user/prompter's side). The threshold for this phenomenon seems more manageable (on both mental and financial terms) in the current crop of LLMs that can be run in a local setup, on either a 48GB Macbook Pro M4 or a 128GB AMD "Strix Halo" Ryzen AI MAX+.

## Current Implementation Status

### ✅ Completed
See [CHANGELOG.md](CHANGELOG.md)

### 🔄 In Progress
- CPU top-level module with integrated register cache, microcode sequencer, stack pointer, instruction ROM, ALU, and value converter
- Verilator --timing registered signal alignment - PC/decode timing ordering issue (PC advances at microcode boundary before next instruction decoded); latched signals capture wrong values; bus writes to incorrect addresses
- Microcode_done signal alignment - latching trigger fires at wrong edge for single-step vs multi-step instructions

### 🔜 Next Steps
- Implement DDR1 memory interface, along with a simulation for the Verilator tests
- Verify OP_ADD two-operand datapath (needs separate B and C operand reads)
- Implement k-table read path for OP_ADDK, OP_SUBK, OP_MULK and other K-operand instructions

### 📔 Backlog
- Verilog lint/typecheck setup
