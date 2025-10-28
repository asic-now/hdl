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

.PHONY: all compile run clean

all:
	@echo "--- Running all DUTS: [$(DUTS)] TESTS: [$(TESTS)] WIDTHS: [$(WIDTHS)] ---"
	@for d in $(DUTS); do \
		for t in $(TESTS); do \
			for w in $(WIDTHS); do \
				$(MAKE) -f $(firstword $(MAKEFILE_LIST)) run DUT=$$d TEST=$$t WIDTH=$$w; \
			done; \
		done; \
	done

compile:
	@echo "--- Compiling DUT: $(DUT) $(WIDTH) ---"
	$(COMPILER) $(COMPILER_FLAGS) -F "$(SRC_FILES_LIST)" -F $(TEST_DIR)/filelist.txt

run: compile
	@echo "--- Running Test: $(TEST) on $(DUT) $(WIDTH) ---"
	$(SIMULATOR) $(SIMULATOR_FLAGS) $(RUN_PLUSARGS)

clean:
	@echo "--- Cleaning up DSim files ---"
	rm -rf *.log *.syn DSim.sln dsim_work/ *.so *.o *.dll
