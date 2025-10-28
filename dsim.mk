# Makefile for compiling and running a generic UVM testbench.
#
# This Makefile is designed to be reusable for different DUTs by
# overriding variables on the command line.
#
# Default DUT: fp_add
# Default Test: combined_test
#
# To run a different test (e.g., fp32_mul):
#   make run DUT=fp32_mul TEST=random_test
#
# Verified on:
# - Windows 11 (64-bit): DSim Studio terminal

SHELL := /bin/bash
MAKEFLAGS += --no-builtin-rules

#==============================================================================
# Configurable Variables (can be overridden from the command line)
#==============================================================================

RESULTS ?= results.log

DUT    ?= fp_add
DUTS   ?= fp_add fp_classify

TEST   ?= combined_test
TESTS  ?= random_test special_cases_test combined_test

WIDTH  ?= 16
WIDTHS ?= 16 32 64

SRC_FILES_LIST   ?= verif/filelist.libs.txt
C_MODEL_FILES    ?= verif/lib/fp16_model.c verif/lib/fp32_model.c verif/lib/fp64_model.c verif/lib/fp_dpi_utils.c

# Set DUTS to a single test if DUT is provided on the command line
ifeq ($(origin DUT), command line)
	DUTS := $(DUT)
endif

# Set TESTS to a single test if TEST is provided on the command line
ifeq ($(origin TEST), command line)
	TESTS := $(TEST)
endif

# Set WIDTHS to a single test if WIDTH is provided on the command line
ifeq ($(origin WIDTH), command line)
	WIDTHS := $(WIDTH)
endif

#==============================================================================
# Static Variables (derived from the above)
#==============================================================================

TB_TOP_NAME      = $(DUT)_tb_top

# DSim Commands
COMPILER = dvlcom
SIMULATOR = dsim

# Project Structure
RTL_LIB_DIR      = rtl/verilog/lib
VERIF_LIB_DIR    = verif/lib
TEST_DIR         = verif/tests/$(DUT)

# Compilation & Run Flags for DSim commands
COMPILER_FLAGS = \
	-lib 'work' \
	-uvm 1.2 \
	+incdir+rtl/verilog/fp \
	+incdir+$(RTL_LIB_DIR) \
	+incdir+$(VERIF_LIB_DIR) \
	+incdir+$(TEST_DIR)

SIMULATOR_FLAGS = \
	-top work.$(TB_TOP_NAME) \
	-uvm 1.2 \
	-defparam WIDTH=$(WIDTH) \
	+acc+b $(C_MODEL_FILES) \
	-c-opts "-shared" \
	-cc-verbose \
	-suppress IneffectiveDynamicCast:UninstVif

# Runtime Plusargs
RUN_PLUSARGS = +UVM_TESTNAME=$(DUT)_$(TEST)

#==============================================================================
# Targets
#==============================================================================

.PHONY: all compile run clean results

all:
	@echo "--- Running all DUTS: [$(DUTS)] TESTS: [$(TESTS)] WIDTHS: [$(WIDTHS)] ---"
	@rm -f $(RESULTS)
	@for d in $(DUTS); do \
		for t in $(TESTS); do \
			for w in $(WIDTHS); do \
				$(MAKE) -f $(firstword $(MAKEFILE_LIST)) run DUT=$$d TEST=$$t WIDTH=$$w; \
			done; \
		done; \
	done;
	@$(MAKE) -f $(firstword $(MAKEFILE_LIST)) results

compile:
	@echo "--- Compiling DUT: $(DUT) $(WIDTH) ---"
	@if ! $(COMPILER) $(COMPILER_FLAGS) -F "$(SRC_FILES_LIST)" -F $(TEST_DIR)/filelist.txt > compile_$(DUT)_$(WIDTH).log 2>&1; then \
		echo "Compilation failed for DUT=$(DUT) WIDTH=$(WIDTH). See compile_$(DUT)_$(WIDTH).log"; \
		echo "$(DUT),$(WIDTH),$(TEST),FAIL (compile)" >> $(RESULTS); \
		exit 1; \
	fi

run: compile
	@# Run simulation and capture result
	@echo "--- Running Test: $(TEST) on $(DUT) $(WIDTH) ---"
	@if $(SIMULATOR) $(SIMULATOR_FLAGS) $(RUN_PLUSARGS) 2>&1 | tee sim_$(DUT)_$(WIDTH)_$(TEST).log | grep -E "UVM_ERROR\s+:\s+[1-9]\d*|UVM_FATAL\s+:\s+[1-9]\d*" > /dev/null; then \
		echo "$(DUT),$(WIDTH),$(TEST),FAIL (sim)" >> $(RESULTS); \
	else \
		echo "$(DUT),$(WIDTH),$(TEST),PASS" >> $(RESULTS); \
	fi

results:
	@echo ""
	@echo "Simulation Summary"
	@echo "========================================================================="
	@printf "%-15s | %-15s | %-9s | %-25s\n" "RESULT" "DUT" "WIDTH" "TEST"
	@printf "%-15s | %-15s | %-9s | %-25s\n" "---------------" "---------------" "---------" "-------------------------"
	@if [ -f $(RESULTS) ]; then \
		cat $(RESULTS) | while IFS=, read -r dut width test result; do \
			printf "%-15s | %-15s | %-9s | %-25s\n" "$$result" "$$dut" "$$width" "$$test"; \
		done; \
		echo "========================================================================="; \
		total_tests=$$(wc -l < $(RESULTS)); \
		pass_count=$$(grep -c "PASS" $(RESULTS)); \
		fail_count=$$(grep -c "FAIL" $(RESULTS)); \
		verdict="PASS"; \
		if [ $$fail_count -gt 0 ]; then \
			verdict="FAIL"; \
		fi; \
		printf "%-15s | Total: %-8d | Pass: %-3d | Fail: %-3d\n" "$$verdict" $$total_tests $$pass_count $$fail_count; \
	else \
		echo "No results found."; \
	fi
	@echo "========================================================================="

clean:
	@echo "--- Cleaning up DSim files ---"
	rm -rf *.log *.syn DSim.sln dsim_work/ *.so *.o *.dll $(RESULTS)
