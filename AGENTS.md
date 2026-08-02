# AGENTS.md — LuaCPU2

## Repo state

No Verilog code exists yet. `src/rtl/` is empty. The only authoritative source is `docs/SPEC.md`.

## Coding conventions (from SPEC.md)

- SystemVerilog allowed
- `snake_case` for all signals, registers, modules
- Synchronous reset (active high), positive clock edge
- Signed arithmetic in ALU ops; two's complement wrapping for unsigned
- FP operations are multi-step microcoded sub-operations

## Pre-commit Checklist
- Update CHANGELOG.md:
  - Append the current completed task to the "Completed" list, with a short description of the features worked on
  - Update the "Test Results" count
- Update README.md:
  - Remove the current completed task from the "Next Steps" list
  - If any part of the current task can be taken on in the next iteration, move the task to the "In Progress" list
  - If any part of the current task should be deferred to a later moment, add these parts to the "Backlog" list


## Next steps
See [README.md](README.md)

## Key constraints

- Register file lives in the stack region of external memory, accessed via bus (not on-chip)
- Internal write-thru cache of 32 registers, LRU, cache misses stall the instruction
- Register mapping: `stack_addr = WB + operand_offset` (no sliding window index)
- 64-bit microcode ROM (1024 entries), variable-length sequences
- NaN-boxed 64-bit data with type tags in bits [51:32]
- Verilog parameters: `PARAM_STACK=256`, `PARAM_KTABLE=256`, `PARAM_PROTOS=256`, `PARAM_UPVALUES=128`, `PARAM_TOTALMEM=4096`, `PARAM_ROMSIZE=4096`
