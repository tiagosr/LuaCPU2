# Spec sheet for LuaCPU

This is the spec sheet for the implementation of a SystemVerilog description of a CPU that runs Lua 5.4-style bytecode. The CPU is a lightly-microcoded architecture with instruction prefetch and a sliding register window into the operand stack, with a microcoded incremental garbage collector, using IEEE 754 64-bit double-precision floats as the default number representation, and a NaN-boxed data representation for other types such as pointers, integer numbers, `nil`, `true` and `false`.

## Verilog coding conventions

- SystemVerilog features allowed
- Signed arithmetic in ALU operations, two's compliment wrapping unsigned arithmetic otherwise
- `snake_case` naming for signals, registers, and modules
- Synchronous reset (active high)
- Positive clock edge for all state updates

## High level structure

The LuaCPU is a hybrid architecture combining microcoded single-cycle execution for simple instructions with multi-cycle finite state machines (FSMs) for complex operations such as table access and garbage collection.

### Datapath

The datapath consists of:
- **Register file**: 256 entries, each 64 bits, stored in the stack region of external memory, accessed through an internal register cache
- **Register cache**: Write-thru cache of 32 registers, reassigned with an LRU policy based on the stack frame register origin. Cache is invalidated on function calls and returns — registers outside the new window range are discarded. On returns, pending writes not destined to return values (registers not marked in OP_RETURN) are discarded. Cache misses trigger a bus access to the stack region and stall the instruction until the data is fulfilled
- **ALU**: unsigned 32-bit primary arithmetic unit, with microcoded IEEE 754 double-precision floating-point support — FP operations (add, mul, div, etc.) are broken into multi-step microcoded sub-operations
- **Fixed-point unit**: signed 32-bit 16.16 fixed-point arithmetic for NaN-boxed fixed-point values
- **PC register**: 32-bit program counter
- **Instruction register (IR)**: 32-bit current instruction
- **Prefetch unit**: fetches the next instruction while the current one executes, hiding one memory latency cycle

### Control unit

The control unit comprises:
- **Microcode ROM**: 1024 entries × 64 bits, mapping macro-opcodes to variable-length microinstruction sequences
- **Microcode sequencer**: drives the microcode ROM, handles micro-branching and sequence termination
- **FSM controllers**: dedicated state machines for table operations (GETTABLE, SETTABLE, GETI, SETI, GETFIELD, SETFIELD) and garbage collection
- **Bus controller**: manages the external memory bus handshake (req/ack/rdy)

### Instruction flow

1. **Fetch**: Prefetch unit reads instruction from ROM or external memory at PC address
2. **Decode**: IR is decoded into opcode key and operands (A, B, C, Bx, Ax, k)
3. **Microcode lookup**: Opcode key maps to a microcode sequence in the ROM
4. **Execute**: Microinstructions drive datapath signals. Simple instructions complete in 1 cycle. Complex instructions (table ops, GC) proceed through multi-cycle FSMs
5. **Commit**: Results written to register file, memory, or PC as specified by microcode

### Stack frame origin

The stack frame origin register (WB) defines the base address of the current function's registers in the stack region of external memory. Register accesses use the stack frame origin plus the operand field offset: register `R[A]` maps to stack address `WB + A`. The cache tracks registers within the current frame range based on an LRU policy. Frame positions are updated by:
- **OP_CALL**: WB advances by the number of arguments (B-1) to make room for the call frame
- **OP_RETURN**: WB retreats by the number of results (B-2) as the call frame is unwound
- **OP_TAILCALL**: WB unchanged (tail call reuses current frame)
- **OP_VARARG / OP_VARARGPREP**: WB adjusted to expose vararg slots
- **OP_SETLIST**: WB may shift to access list elements

## Instruction set

The instruction set is encoded in 32-bit opcodes, with separate but related encodings:

Encoding 1:
| field C | field B | flag k | field A | key |
| --- | --- | --- | --- | --- |
| 8 bits | 8 bits | 1 bit | 8 bits | 7 bits |

Encoding 2:
| field Bx | field A | key |
| --- | --- | --- |
| 17 bits | 8 bits | 7 bits |

Encoding 3:
| field Ax | key |
| --- | --- |
| 25 bits | 7 bits |

Opcode table:
| key | mnemonic | encoding | pseudocode |
| --- | --- | --- | --- |
| 0x00 | OP_MOVE | 1 | `R[A] = R[B]` |
| 0x01 | OP_LOADI | 2 | `R[A] = sBx` |
| 0x02 | OP_LOADF | 2 | `R[A] = (number)sBx` |
| 0x03 | OP_LOADK | 2 | `R[A] = K[Bx]` |
| 0x04 | OP_LOADKX | 1 | `R[A] = K[extraArg.Ax]` |
| 0x05 | OP_LOADFALSE | 1 | `R[A] = false` |
| 0x06 | OP_LFALSESKIP | 1 | `R[A] = false; pc++` |
| 0x07 | OP_LOADTRUE | 1 | `R[A] = true` |
| 0x08 | OP_LOADNIL | 1 | `R[A], R[A+1], ..., R[A+B] := nil` |
| 0x09 | OP_GETUPVAL | 1 | `R[A] := UpValue[B]` |
| 0x0A | OP_SETUPVAL | 1 | `UpValue[B] := R[A]` |
| 0x0B | OP_GETTABUP | 1 | `R[A] := UpValue[B][K[C]:shortstring]` |
| 0x0C | OP_GETTABLE | 1 | `R[A] := R[B][R[C]]` |
| 0x0D | OP_GETI | 1 | `R[A] := R[B][C]` |
| 0x0E | OP_GETFIELD | 1 | `R[A] := R[B][K[C]:shortstring]` |
| 0x0F | OP_SETTABUP | 1 | `UpValue[A][K[B]:shortstring] := RK(C)` | 
| 0x10 | OP_SETTABLE | 1 | `R[A][R[B]] := RK(C)` |
| 0x11 | OP_SETI | 1 | `R[A][B] := RK(C)` |
| 0x12 | OP_SETFIELD | 1 | `R[A][K[B]:shortstring] := RK(C)` |
| 0x13 | OP_NEWTABLE | 1 | `R[A] := {}` * |
| 0x14 | OP_SELF | 1 | `R[A+1] := R[B]; R[A] := R[B][RK(C):string]` |
| 0x15 | OP_ADDI | 1 | `R[A] := R[B] + sC` |
| 0x16 | OP_ADDK | 1 | `R[A] := R[B] + K[C]:number` |
| 0x17 | OP_SUBK | 1 | `R[A] := R[B] - K[C]:number` |
| 0x18 | OP_MULK | 1 | `R[A] := R[B] * K[C]:number` |
| 0x19 | OP_MODK | 1 | `R[A] := R[B] % K[C]:number` |
| 0x1A | OP_POWK | 1 | `R[A] := R[B] ^ K[C]:number` |
| 0x1B | OP_DIVK | 1 | `R[A] := R[B] / K[C]:number` |
| 0x1C | OP_IDIVK | 1 | `R[A] := R[B] // K[C]:number` |
| 0x1D | OP_BANDK | 1 | `R[A] := R[B] & K[C]:integer` |
| 0x1E | OP_BORK | 1 | `R[A] := R[B] \| K[C]:integer` |
| 0x1F | OP_BXORK | 1 | `R[A] := R[B] ~ K[C]:integer` |
| 0x20 | OP_SHRI | 1 | `R[A] := R[B] >> sC` |
| 0x21 | OP_SHLI | 1 | `R[A] := sC << R[B]` |
| 0x22 | OP_ADD | 1 | `R[A] := R[B] + R[C]` |
| 0x23 | OP_SUB | 1 | `R[A] := R[B] - R[C]` |
| 0x24 | OP_MUL | 1 | `R[A] := R[B] * R[C]` |
| 0x25 | OP_MOD | 1 | `R[A] := R[B] % R[C]` |
| 0x26 | OP_POW | 1 | `R[A] := R[B] ^ R[C]` |
| 0x27 | OP_DIV | 1 | `R[A] := R[B] / R[C]` |
| 0x28 | OP_IDIV | 1 | `R[A] := R[B] // R[C]` |
| 0x29 | OP_BAND | 1 | `R[A] := R[B] & R[C]` |
| 0x2A | OP_BOR | 1 | `R[A] := R[B] \| R[C]` |
| 0x2B | OP_BXOR | 1 | `R[A] := R[B] ~ R[C]` |
| 0x2C | OP_SHL | 1 | `R[A] := R[B] << R[C]` |
| 0x2D | OP_SHR | 1 | `R[A] := R[B] >> R[C]` |
| 0x2E | OP_MMBIN | 1 | call C metamethod over R[A] and R[B] |
| 0x2F | OP_MMBINI | 1 | call C metamethod over R[A] and sB. <br>In OP_MMBINI/OP_MMBINK, k means the arguments were flipped (the constant is the first operand) |
| 0x30 | OP_MMBINK | 1 | call C metamethod over R[A] and K[B] |
| 0x31 | OP_UNM | 1 | `R[A] := -R[B]` |
| 0x32 | OP_BNOT | 1 | `R[A] := ~R[B]` |
| 0x33 | OP_NOT | 1 | `R[A] := not R[B]` |
| 0x34 | OP_LEN | 1 | `R[A] := #R[B]` (length operator)  |
| 0x35 | OP_CONCAT | 1 | `R[A] := R[A].. ... ..R[A + B - 1]` |
| 0x36 | OP_CLOSE | 1 | close all upvalues >= R[A] |
| 0x37 | OP_TBC | 1 |  mark variable A "to be closed" |
| 0x38 | OP_JMP | 3 | `pc += sAx` |
| 0x39 | OP_EQ | 1 | `if ((R[A] == R[B]) ~= k) then pc++` <br>For comparisons, k specifies what condition the test should accept (true or false). All 'skips' (pc++) assume that next instruction is a jump. |
| 0x3A | OP_LT | 1 | `if ((R[A] <  R[B]) ~= k) then pc++` |
| 0x3B | OP_LE | 1 | `if ((R[A] <= R[B]) ~= k) then pc++` |
| 0x3C | OP_EQK | 1 | `if ((R[A] == K[B]) ~= k) then pc++` |
| 0x3D | OP_EQI | 1 | `if ((R[A] == sB) ~= k) then pc++` <br>In comparisons with an immediate operand, C signals whether the original operand was a float. (It must be corrected in case of metamethods.) |
| 0x3E | OP_LTI | 1 | `if ((R[A] < sB) ~= k) then pc++` |
| 0x3F | OP_LEI | 1 | `if ((R[A] <= sB) ~= k) then pc++` |
| 0x40 | OP_GTI | 1 | `if ((R[A] > sB) ~= k) then pc++` |
| 0x41 | OP_GEI | 1 | `if ((R[A] >= sB) ~= k) then pc++` |
| 0x42 | OP_TEST | 1 | `if (not R[A] == k) then pc++` |
| 0x43 | OP_TESTSET | 1 | `if (not R[B] == k) then pc++ else R[A] := R[B]` <br>Opcode OP_TESTSET is used in short-circuit expressions that need both to jump and to produce a value, such as (a = b or c) |
| 0x44 | OP_CALL | 1 | `R[A], ... ,R[A+C-2] := R[A](R[A+1], ... ,R[A+B-1])` <br>In OP_CALL, if (B == 0) then B = top - A. <br>If (C == 0), then 'top' is set to last_result+1, so next open instruction (OP_CALL, OP_RETURN*, OP_SETLIST) may use 'top'. |
| 0x45 | OP_TAILCALL | 1 | `return R[A](R[A+1], ... ,R[A+B-1])` <br>In instructions OP_RETURN/OP_TAILCALL, 'k' specifies that the function builds upvalues, which may need to be closed. C > 0 means the function is vararg, so that its 'func' must be corrected before returning; in this case, (C - 1) is its number of fixed parameters. |
| 0x46 | OP_RETURN | 1 | `return R[A], ... ,R[A+B-2]` <br>In OP_RETURN, if (B == 0) then return up to 'top'. |
| 0x47 | OP_RETURN0 | 1 | `return` |
| 0x48 | OP_RETURN1 | 1 | `return R[A]` |
| 0x49 | OP_FORLOOP | 2 | `update counters; if loop continues then pc-=Bx;` |
| 0x4A | OP_FORPREP | 2 |  `<check values and prepare counters>; if not to run then pc+=Bx+1;` |
| 0x4B | OP_TFORPREP | 2 | `create upvalue for R[A + 3]; pc+=Bx` |
| 0x4C | OP_TFORCALL | 1 | `R[A+4], ... ,R[A+3+C] := R[A](R[A+1], R[A+2]);` |
| 0x4D | OP_TFORLOOP | 2 | `if R[A+2] ~= nil then { R[A]=R[A+2]; pc -= Bx }` |
| 0x4E | OP_SETLIST | 1 | `R[A][C+i] := R[A+i], 1 <= i <= B` <br>In OP_SETLIST, if (B == 0) then real B = 'top'; if k, then real C = EXTRAARG _ C (the bits of EXTRAARG concatenated with the bits of C). |
| 0x4F | OP_CLOSURE | 2 | `R[A] := closure(KPROTO[Bx])`       |
| 0x50 | OP_VARARG | 1 | `R[A], R[A+1], ..., R[A+C-2] = vararg` <br>In OP_VARARG, if (C == 0) then use actual number of varargs and set top (like in OP_CALL with C == 0). |
| 0x51 | OP_VARARGPREP | 1 | (adjust vararg parameters) |
| 0x52 | OP_EXTRAARG | 3 | extra (larger) argument for previous opcode |

* Opcode OP_LFALSESKIP is used to convert a condition to a boolean value, in a code equivalent to (not cond ? false : true).  (It produces false and skips the next instruction producing true.)

* Opcodes OP_MMBIN and variants follow each arithmetic and bitwise opcode. If the operation succeeds, it skips this next opcode. Otherwise, this opcode calls the corresponding metamethod.

* Opcode OP_TESTSET is used in short-circuit expressions that need both to jump and to produce a value, such as (a = b or c).

* In OP_CALL, if (B == 0) then B = top - A. If (C == 0), then 'top' is set to last_result+1, so next open instruction (OP_CALL, OP_RETURN*, OP_SETLIST) may use 'top'.

* In OP_VARARG, if (C == 0) then use actual number of varargs and set top (like in OP_CALL with C == 0).

* In OP_RETURN, if (B == 0) then return up to 'top'.

* In OP_LOADKX and OP_NEWTABLE, the next instruction is always OP_EXTRAARG.

* In OP_SETLIST, if (B == 0) then real B = 'top'; if k, then real C = EXTRAARG _ C (the bits of EXTRAARG concatenated with the bits of C).

* In OP_NEWTABLE, B is log2 of the hash size (which is always a power of 2) plus 1, or zero for size zero. If not k, the array size is C. Otherwise, the array size is EXTRAARG _ C.

* For comparisons, k specifies what condition the test should accept (true or false).

* In OP_MMBINI/OP_MMBINK, k means the arguments were flipped (the constant is the first operand).

* All 'skips' (pc++) assume that next instruction is a jump.

* In instructions OP_RETURN/OP_TAILCALL, 'k' specifies that the function builds upvalues, which may need to be closed. C > 0 means the function is vararg, so that its 'func' must be corrected before returning; in this case, (C - 1) is its number of fixed parameters.

* In comparisons with an immediate operand, C signals whether the original operand was a float. (It must be corrected in case of metamethods.)

## Data representation

### NaN-boxed values

All Lua values are encoded in 64 bits using a NaN-boxing scheme. The upper bits of the mantissa (bits [51:32]) serve as a type tag. Bits [31:0] hold the value payload or pointer.

| tag [51:32] | type | bits [31:0] content |
| --- | --- | --- |
| any NaN/non-NaN pattern (no specific tag) | double (IEEE 754 64-bit) | bits [31:0] of mantissa |
| `0xffff0` | integer | signed 32-bit integer value |
| `0xffff2` | fixed-point | signed 32-bit 16.16 fixed-point number |
| `0xffff3` | userdata | 32-bit pointer to userdata object in external memory |
| `0xffff4` | table | 32-bit pointer to table object in external memory |
| `0xffff7` | function | 32-bit pointer to function/closure object in external memory |
| `0xffff8` | proto | 32-bit pointer to prototype object in external memory |
| `0xffff9` | thread | 32-bit pointer to thread object in external memory |
| `0xffffb` | string | 32-bit pointer to string object in external memory |
| `0xffffc` | light userdata | 32-bit pointer to light userdata |
| `0xffffd` | true | 32'h0000_0001 (payload ignored) |
| `0xffffe` | false | 32'h0000_0000 (payload ignored) |
| `0xfffff` | nil | 32'h0000_00000 (payload ignored) |

### Type detection and unboxing

The ALU and control logic detect the type tag in bits [52:32] to determine how to interpret bits [31:0]:
- **Double**: any NaN with tag not matching any specific type constant. The full 64 bits are passed to the floating-point unit
- **Integer**: tag `0xffff0`. Bits [31:0] are extracted as a signed 32-bit integer
- **Fixed-point**: tag `0xffff2`. Bits [31:0] are interpreted as signed 16.16 fixed-point (16 integer bits, 16 fractional bits)
- **Pointer types**: tags `0xffff3` through `0xffffc`. Bits [31:0] are 32-bit memory addresses used for external memory accesses
- **Boolean/nil**: tags `0xffffd`, `0xffffe`, `0xfffff`. No payload data

### Mixed-type arithmetic

When operands have different types:
- **Double + Double**: IEEE 754 floating-point operation, result is double
- **Integer + Integer**: 32-bit unsigned integer operation, result is integer
- **Fixed-point + Fixed-point**: 16.16 fixed-point operation, result is fixed-point
- **Double + Integer**: integer is converted to double, result is double
- **Double + Fixed-point**: fixed-point is converted to double (by dividing payload by 65536), result is double
- **Integer + Fixed-point**: integer is converted to fixed-point (payload multiplied by 65536), result is fixed-point
- **Any + Pointer type**: type error (halts CPU with error flag)

## Memory architecture

### External memory bus

The CPU accesses external memory via a simple custom bus with the following protocol:

| signal | direction | width | description |
| --- | --- | --- | --- |
| `bus_addr` | CPU → external | 32 bits | memory address |
| `bus_data_out` | CPU → external | 32 bits | data to write |
| `bus_data_in` | external → CPU | 32 bits | data read from memory |
| `bus_req` | CPU → external | 1 bit | read/write request asserted |
| `bus_ack` | external → CPU | 1 bit | request acknowledged |
| `bus_rdy` | external → CPU | 1 bit | memory ready (may be deasserted for variable latency) |
| `bus_wr` | CPU → external | 1 bit | write (1) or read (0) |

Handshake protocol:
1. CPU asserts `bus_req` with `bus_addr`, `bus_wr`, and optionally `bus_data_out`
2. External memory asserts `bus_rdy` when ready to accept the request
3. On the next clock edge after both `bus_req` and `bus_rdy` are asserted, the transfer occurs
4. For reads: `bus_data_in` is valid on the clock edge after `bus_ack` is asserted
5. For writes: no data return, `bus_ack` confirms completion
6. CPU deasserts `bus_req` when done

Burst transfers are not supported. Each access is a single 32-bit word.

### Memory regions

External memory is divided into parameterized regions. All sizes are in 32-bit words.

| parameter | default | region |
| --- | --- | --- |
| `PARAM_STACK` | 256 | operand stack (dynamic, grows upward) |
| `PARAM_KTABLE` | 256 | constant table (K[]) |
| `PARAM_PROTOS` | 256 | prototype table (function prototypes) |
| `PARAM_UPVALUES` | 128 | upvalue table |
| `PARAM_TOTALMEM` | 4096 | total external memory size |

Memory layout is defined by the Lua runtime environment. The stack occupies the lowest addresses, followed by the k-table, proto table, and upvalue table. Object data (tables, strings, closures, userdata) occupies the remaining space. The exact layout is managed by the Lua allocator and garbage collector.

### Instruction memory (ROM)

Lua bytecode is stored in an on-chip ROM:

| parameter | default | description |
| --- | --- | --- |
| `PARAM_ROMSIZE` | 4096 | ROM size in 32-bit words |

The entry point function starts at ROM address 0. The ROM is readable only (no writes). The prefetch unit reads from the ROM at the PC address.

## Microcode

### Microcode ROM

- Depth: 1024 microinstruction entries
- Width: 64 bits per microinstruction
- Organization: macro-opcode keys (7 bits, 0x00-0x52) map to variable-length microinstruction sequences

### Microinstruction format (64 bits)

| field | bits | width | description |
| --- | --- | --- | --- |
| `alu_op` | [63:59] | 5 bits | ALU operation selection (add, sub, mul, div, mod, pow, idiv, and, or, xor, shl, shr, neg, not, bnot, compare, float_op, fixed_op, convert, pass, etc.) |
| `reg_a_write` | [58:55] | 4 bits | Register A write destination (window index, or special values for PC, WB, error flag, GC counter) |
| `reg_b_read` | [54:51] | 4 bits | Register B read source (window index, or special values for WB, stack pointer, top marker) |
| `reg_c_read` | [50:47] | 4 bits | Register C read source (window index, or special values for WB, stack pointer) |
| `mem_op` | [46:44] | 3 bits | Memory operation (read stack, read ktable, read proto, read upvalue, write stack, write ktable, write object, no access) |
| `pc_op` | [43:41] | 3 bits | PC operation (increment, jump offset, micro-branch target, no change, PC from register) |
| `micro_branch` | [40:39] | 2 bits | Microcode branching (continue to next micro-op, branch to ROM address, terminate sequence, conditional branch on ALU flag) |
| `gc_step` | [38:37] | 2 bits | Garbage collector step (no GC, mark phase, unmark phase, sweep phase, scan object) |
| `stack_op` | [36:35] | 2 bits | Window base register operation (no change, advance by N, retreat by N, set to value) |
| `enable` | [34] | 1 bit | Microinstruction enable (0 = NOP/stall, 1 = execute) |
| `immediate` | [33:0] | 34 bits | Immediate data / offset / micro-branch target / GC threshold / window adjustment value |

### Variable-length microcode sequences

Each macro-opcode maps to a sequence of microinstructions terminated by `micro_branch = terminate` (binary `11`). Simple instructions (OP_MOVE, OP_LOADI, OP_LOADTRUE) may use a single microinstruction. Complex instructions (OP_CALL, OP_GETTABLE, OP_SETTABLE) use sequences of 3-10 microinstructions interleaved with FSM control.

## Table operations FSM

Table access instructions (GETTABLE, SETTABLE, GETI, SETI, GETFIELD, SETFIELD, OP_SELF, OP_SETLIST) are executed by a dedicated FSM with variable cycle counts depending on the access path.

### Cycle counts

| operation | path | cycles | description |
| --- | --- | --- | --- |
| GETI / SETI | array access | 2 | Key is integer C, direct array index lookup |
| GETFIELD / SETFIELD | field access | 3 | Key is short string from k-table, hash lookup |
| GETTABLE / SETTABLE | hash hit | 3 | Key is register value, hash lookup finds entry |
| GETTABLE / SETTABLE | hash miss / metamethod | 5 | Hash lookup fails or metamethod (`__index`/`__newindex`) must be dispatched |
| OP_SELF | method lookup | 3 | Similar to GETTABLE field access + register write for self |
| OP_SETLIST | array fill | B+1 cycles | Writes B consecutive elements to array (1 cycle per element) |

### FSM sequence (GETTABLE example, hash hit path)

1. **Cycle 1**: Resolve key from register C (NaN-box type detection, unbox if integer/double)
2. **Cycle 2**: Read table object from register B (pointer dereference via bus), read table hash array
3. **Cycle 3**: Compute hash of key, lookup entry, read value, write to register A

### FSM sequence (hash miss / metamethod path)

1. **Cycle 1**: Resolve key from register C
2. **Cycle 2**: Read table object, compute hash, miss detected
3. **Cycle 3**: Read `__index` metamethod from table or upvalue chain
4. **Cycle 4**: Prepare metamethod call arguments (table, key)
5. **Cycle 5**: Invoke metamethod via OP_CALL microcode sequence (may itself be multi-cycle)

## Garbage collector

### Algorithm

Incremental mark-sweep garbage collector, interleaved with instruction execution.

### Trigger and budget

Both trigger threshold and per-cycle step budget are parameterized:

| parameter | default | description |
| --- | --- | --- |
| `PARAM_GC_TRIGGER` | (parameterized) | Number of allocations before GC is triggered |
| `PARAM_GC_STEPS_PER_CYCLE` | (parameterized) | Maximum GC steps performed per instruction cycle |

Trigger mechanism:
- An allocation counter increments on each object creation (NEWTABLE, OP_CLOSURE, OP_NEWTABLE, string allocation, userdata creation)
- When the counter reaches `PARAM_GC_TRIGGER`, the GC is flagged as pending
- The GC begins executing on the next cycle, performing up to `PARAM_GC_STEPS_PER_CYCLE` steps per cycle
- GC completes when all objects are swept and free list is rebuilt

### GC phases

| phase | gc_step micro-op | description |
| --- | --- | --- |
| Mark | `01` | Traverse reachable objects from root set (stack registers, upvalues, protos), marking each object as live |
| Unmark | `10` | Clear marks on unreachable objects (preparation for sweep) |
| Sweep | `11` | Free unmarked objects, return to free list, update object pointers |
| Scan | `00` (special) | Scan a single object's references during mark phase |

### GC interleaving

When GC is active, the microcode sequencer inserts GC steps into the instruction execution flow. The `gc_step` field in microinstructions directs the GC FSM to perform its current step. Instruction execution continues in parallel where possible (GC reads object metadata from memory while ALU processes instruction data). If GC requires the same memory bus port as the instruction, the instruction stalls for one cycle.

## I/O

### UART interface

Initial I/O implementation uses a simple UART for stdin/stdout:

| parameter | default | description |
| --- | --- | --- |
| `PARAM_UART_BAUD` | (parameterized) | Baud rate (configurable) |

UART characteristics:
- 8 data bits, no parity, 1 stop bit (8N1)
- Configurable baud rate via parameter
- Non-blocking operation with 16-character FIFO for both transmit and receive
- Lua I/O operations (print, read, file ops) map to UART character send/receive
- Future extension: custom I/O bus for block transfers and additional peripherals

### UART signals

| signal | direction | width | description |
| --- | --- | --- | --- |
| `uart_tx` | CPU → external | 1 bit | transmit bit |
| `uart_rx` | external → CPU | 1 bit | receive bit |
| `uart_tx_rdy` | UART → CPU | 1 bit | transmitter ready for new character |
| `uart_rx_rdy` | UART → CPU | 1 bit | receiver has character available |

## Error handling

### Error conditions

The CPU halts on the following error conditions:
- Division by zero (OP_DIV, OP_DIVK, OP_IDIV, OP_IDIVK)
- Invalid memory access (address outside PARAM_TOTALMEM)
- Stack overflow (stack pointer exceeds PARAM_STACK boundary)
- Lua runtime errors (type mismatch in operations, invalid opcode)
- Metamethod invocation failure

### Error state

When an error occurs:
- `error_flag` signal is asserted (1 bit, synchronous)
- CPU halts: PC stops incrementing, no further microinstructions execute
- `halt_flag` signal is asserted to indicate CPU is stopped
- Error code (if available) is stored in a dedicated error register
- External logic must assert reset to recover

### Error signals

| signal | direction | width | description |
| --- | --- | --- | --- |
| `error_flag` | CPU → external | 1 bit | CPU detected an error |
| `halt_flag` | CPU → external | 1 bit | CPU is halted (due to error or other condition) |
| `error_code` | CPU → external | 8 bits | error type code (optional, implementation-dependent) |

## Reset behavior

### Initial state on reset

On synchronous reset (reset asserted on positive clock edge):

| component | initial value |
| --- | --- |
| PC | 0 (ROM entry point) |
| Window base (WB) | 0 |
| Stack pointer | 0 (empty stack) |
| Stack region | all entries zero |
| Microcode sequencer | microinstruction index 0 |
| GC allocation counter | 0 |
| GC state | idle (no GC pending) |
| Error flag | 0 (no error) |
| Halt flag | 0 |
| Bus controller | idle (no pending transaction) |
| UART FIFOs | empty |
| Prefetch unit | prefetching ROM address 1 |

### Boot sequence

1. Reset completes, all state initialized to defaults
2. PC = 0, prefetch unit loads bytecode from ROM address 0
3. First instruction decoded and executed from ROM entry point
4. The entry point bytecode must invoke the initial Lua function (typically via OP_CALL or direct execution)
5. Stack grows as functions are called, window base adjusts accordingly

## Performance targets

- **Average cycles per instruction**: 3-5 cycles (including microcode sequences, memory accesses, and GC interleaving)
- **Clock frequency**: not specifically targeted; depends on FPGA implementation and timing closure
- **Simple instructions** (OP_MOVE, OP_LOADI, OP_LOADTRUE): 1-2 cycles
- **Arithmetic instructions** (OP_ADD, OP_SUB, OP_MUL): 2-3 cycles (including potential OP_MMBIN)
- **Table operations**: 2-5 cycles as specified in FSM section
- **Call/return** (OP_CALL, OP_RETURN): 3-6 cycles (stack manipulation + window adjustment)
- **GC interference**: adds 0-1 cycles per instruction when GC is active

## Testbench and verification

### Verification approach

The CPU should be verified using a SystemVerilog testbench with the following methodology:

1. **ROM preload**: Testbench loads Lua bytecode into the CPU's ROM (via a testbench interface, simulating the ROM content)
2. **External memory simulation**: Testbench provides a model of external memory (stack, k-table, protos, upvalues, object data) with Lua semantics
3. **Reference comparison**: A host-side Lua 5.4 interpreter runs the same bytecode; CPU output is compared against the reference interpreter's output
4. **UART capture**: Testbench captures UART tx output and compares against reference interpreter's stdout

### Test cases

Recommended test coverage:
- **Arithmetic**: all OP_ADD, OP_SUB, OP_MUL, OP_DIV, OP_MOD, OP_POW, OP_IDIV variants (with constants and registers, double and integer operands)
- **Bitwise**: all OP_BAND, OP_BOR, OP_BXOR, OP_SHL, OP_SHR variants
- **Comparisons**: all OP_EQ, OP_LT, OP_LE, OP_GT, OP_GE variants with k flag, including constant and immediate versions
- **Table operations**: GETTABLE, SETTABLE, GETI, SETI, GETFIELD, SETFIELD with array and hash access, metamethod dispatch
- **Control flow**: OP_JMP, OP_CALL, OP_TAILCALL, OP_RETURN, OP_FORLOOP, OP_FORPREP, OP_TFORPREP, OP_TFORCALL, OP_TFORLOOP
- **Closure and upvalues**: OP_CLOSURE, OP_GETUPVAL, OP_SETUPVAL, OP_CLOSE, OP_TBC
- **NaN-boxing**: type detection, unboxing, mixed-type arithmetic, type conversion
- **Fixed-point**: 16.16 arithmetic, conversion to/from double
- **Garbage collection**: allocation triggering, mark-sweep phases, object lifecycle
- **Error handling**: division by zero, stack overflow, type errors
- **UART I/O**: character send/receive, FIFO behavior

### Verification signals

Testbench monitors the following signals:
- `error_flag` and `halt_flag` (should remain 0 for correct execution)
- `uart_tx` (captured character stream)
- Register file contents at key points (after OP_CALL, OP_RETURN, etc.)
- External memory accesses (bus_addr, bus_data_out, bus_data_in)
- Instruction count and cycle count for performance measurement
