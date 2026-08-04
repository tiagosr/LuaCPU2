SHELL := /bin/bash

VERILATOR := verilator
IVERILOG := iverilog
VVP := vvp

CPU_SRC := ../src/rtl/microcode_mnemonics.sv ../src/rtl/opcode_mnemonics.sv ../src/rtl/reg_cache.sv ../src/rtl/alu.sv ../src/rtl/value_conv.sv ../src/rtl/microcode_rom.sv ../src/rtl/stack_ptr.sv ../src/rtl/instr_rom.sv ../src/rtl/cpu.sv
TB_SRC := cpu_tb.sv
MEM_SRC := mem_model.sv
UART_SRC := uart_model.sv
MAIN_SRC := main.cpp
INC_DIRS := ../src/rtl/

BUILD_DIR := build
VCD := trace.vcd
SIM_VERILATOR := $(BUILD_DIR)/Vcpu_tb
SIM_IVERILOG := $(BUILD_DIR)/cpu_tb_sim

.PHONY: all clean run_verilator run_iverilog

all: run_verilator

run_verilator: $(SIM_VERILATOR)
	@echo "=== Running Verilator simulation ==="
	$(SIM_VERILATOR)
	@if [ -f $(VCD) ]; then echo "VCD trace: $(VCD)"; fi

run_iverilog: $(SIM_IVERILOG)
	@echo "=== Running Icarus Verilog simulation ==="
	vvp $(SIM_IVERILOG)
	@if [ -f $(VCD) ]; then echo "VCD trace: $(VCD)"; fi

$(SIM_VERILATOR): $(CPU_SRC) $(TB_SRC) $(MEM_SRC) $(UART_SRC) $(MAIN_SRC)
	@mkdir -p $(BUILD_DIR)
	$(VERILATOR) --trace \
		--cc \
		--exe \
		--top-module cpu_tb \
		--Mdir $(BUILD_DIR) \
		--timing \
		-CFLAGS "-O2" \
		$(INC_DIRS:%=-I%) \
		$(CPU_SRC) \
		$(TB_SRC) \
		$(MEM_SRC) \
		$(UART_SRC) \
		$(MAIN_SRC) \
		--build
	@echo "=== Verilator build complete ==="

$(SIM_IVERILOG): $(CPU_SRC) $(TB_SRC) $(MEM_SRC) $(UART_SRC)
	@mkdir -p $(BUILD_DIR)
	$(IVERILOG) -o $(SIM_IVERILOG) \
		-g2009 \
		$(INC_DIRS:%=-I%) \
		$(CPU_SRC) \
		$(TB_SRC) \
		$(MEM_SRC) \
		$(UART_SRC)
	@echo "=== Icarus Verilog build complete ==="

clean:
	rm -rf $(BUILD_DIR)
	rm -f $(VCD)
	rm -f *.dat
	@echo "=== Clean complete ==="
