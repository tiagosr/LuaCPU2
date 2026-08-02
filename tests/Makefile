SHELL := /bin/bash

VERILATOR := verilator

CPU_SRC := ../src/rtl/cpu.sv ../src/rtl/reg_cache.sv ../src/rtl/microcode_rom.sv ../src/rtl/microcode_seq.sv ../src/rtl/stack_ptr.sv ../src/rtl/instr_rom.sv ../src/rtl/alu.sv ../src/rtl/value_conv.sv
TB_SRC := cpu_tb.sv
MEM_SRC := mem_model.sv
UART_SRC := uart_model.sv
MAIN_SRC := main.cpp

BUILD_DIR := build
VCD := trace.vcd

.PHONY: all clean run

all: run

run: $(BUILD_DIR)/Vcpu_tb
	@echo "=== Running simulation ==="
	$(BUILD_DIR)/Vcpu_tb
	@if [ -f $(VCD) ]; then echo "VCD trace: $(VCD)"; fi

$(BUILD_DIR)/Vcpu_tb: $(CPU_SRC) $(TB_SRC) $(MEM_SRC) $(UART_SRC) $(MAIN_SRC)
	@mkdir -p $(BUILD_DIR)
	$(VERILATOR) --trace \
		--cc \
		--exe \
		--top-module cpu_tb \
		--Mdir $(BUILD_DIR) \
		--timing \
		-CFLAGS "-O2" \
		$(CPU_SRC) \
		$(TB_SRC) \
		$(MEM_SRC) \
		$(UART_SRC) \
		$(MAIN_SRC) \
		--build
	@echo "=== Build complete ==="

clean:
	rm -rf $(BUILD_DIR)
	rm -f $(VCD)
	rm -f *.dat
	@echo "=== Clean complete ==="
