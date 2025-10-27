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

DUT       ?= fp_add
PRECISION ?= fp16

PRECISIONS ?= fp16 fp32 fp64

DUTS  ?= fp_add fp_classify

TEST  ?= combined_test
TESTS ?= random_test special_cases_test combined_test

SRC_FILES_LIST   ?= verif/filelist.txt
C_MODEL_FILES    ?= verif/lib/fp16_model.c verif/lib/fp32_model.c verif/lib/fp64_model.c verif/lib/fp_dpi_utils.c

#==============================================================================
# Static Variables (derived from the above)
#==============================================================================
# DUT_PREFIX       = $(word 1, $(subst _, ,$(DUT))) # e.g., fp16
TB_TOP_NAME      = $(DUT)_tb_top

# DSim Commands
COMPILER = dvlcom
SIMULATOR = dsim

# Project Structure
RTL_LIB_DIR      = rtl/verilog/lib
# RTL_DIR          = rtl/verilog/$(DUT_PREFIX)
VERIF_LIB_DIR    = verif/lib
# TEST_DIR         = verif/tests/$(DUT)

# Set parameters based on precision
ifeq ($(PRECISION),fp16)
	WIDTH=16
else ifeq ($(PRECISION),fp32)
	WIDTH=32
else ifeq ($(PRECISION),fp64)
	WIDTH=64
endif

# Source Files
# DUT_FILE         = $(RTL_DIR)/$(DUT).v
# TB_PKG_FILE      = $(TEST_DIR)/$(DUT)_pkg.sv
# TB_TOP_FILE      = $(TEST_DIR)/$(TB_TOP_NAME).sv

# Compilation & Run Flags for DSim commands
COMPILER_FLAGS = \
	-lib 'work' \
	-uvm 1.2 \
	+define+WIDTH=$(WIDTH) \
	+incdir+rtl/verilog/fp \
	+incdir+$(RTL_LIB_DIR) \
	+incdir+$(VERIF_LIB_DIR) \
	+incdir+verif/tests/$(DUT) \
	+incdir+verif/tests/fp16_classify

SIMULATOR_FLAGS = \
	-top work.$(TB_TOP_NAME) \
	-uvm 1.2 \
	+acc+b $(C_MODEL_FILES) \
	-c-opts "-shared" \
	-cc-verbose \
	-suppress IneffectiveDynamicCast:UninstVif

# Runtime Plusargs
#RUN_PLUSARGS = +UVM_TESTNAME=$(PRECISION)_add_$(TEST)
RUN_PLUSARGS = +UVM_TESTNAME=$(DUT)_$(TEST)

#==============================================================================
# Targets
#==============================================================================

.PHONY: all compile run clean

all:
	@$(foreach p,$(PRECISIONS),$(MAKE) -f $(firstword $(MAKEFILE_LIST)) run DUT=$(DUT) PRECISION=$(p) TEST=$(TEST);)

compile:
	@echo "--- Compiling DUT: $(DUT) ---"
	$(COMPILER) $(COMPILER_FLAGS) -F "$(SRC_FILES_LIST)"

run: compile
	@echo "--- Running Test: $(TEST) on $(DUT) ---"
	$(SIMULATOR) $(SIMULATOR_FLAGS) $(RUN_PLUSARGS)

clean:
	@echo "--- Cleaning up DSim files ---"
	rm -rf *.log *.syn DSim.sln dsim_work/ *.so *.o *.dll
