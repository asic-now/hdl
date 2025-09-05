# Makefile for compiling and running the UVM testbench for the FP16 Adder.
#
# Assumes this Makefile is in the project root, with 'rtl/' and 'verif/' subdirectories.
#
# Usage:
#   make compile      - Compiles the DUT and testbench.
#   make run          - Runs the default test (fp16_add_random_test).
#   make run TESTNAME=<test_class_name> - Runs a specific test.
#   make all          - Compiles and runs the default test.
#   make clean        - Removes all generated simulation files.
#

#==============================================================================
# Variables
#==============================================================================

# Simulator command (can be changed to irun, vsim, etc. with syntax adjustments)
COMPILER = vcs

# Default test to run if not specified on the command line
TESTNAME ?= fp16_add_random_test

# Project Structure
RTL_DIR      = rtl/verilog/fp16
TEST_DIR     = verif/tests/fp16_add
VERIF_LIB_DIR= verif/lib

# Source Files
DUT_FILES = $(RTL_DIR)/fp16_add.v
TB_TOP_FILE = $(TEST_DIR)/fp16_add_tb_top.sv

# Include paths for the compiler
INCLUDE_DIRS = +incdir+$(VERIF_LIB_DIR) +incdir+$(TEST_DIR)

# Compilation Flags
# -sverilog     : Enable SystemVerilog
# -full64       : Use 64-bit mode
# -ntb_opts uvm : Enable UVM and associated packages
# -debug_access+all : Enable full debug capabilities for DVE/Verdi
COMPILE_FLAGS = \
	-sverilog \
	-full64 \
	-ntb_opts uvm \
	-debug_access+all \
	-timescale=1ns/1ps

# Runtime Flags
# +UVM_TESTNAME : Specifies which UVM test to run
# -l run.log    : Redirects simulation output to a log file
RUN_FLAGS = \
	+UVM_TESTNAME=$(TESTNAME) \
	-l run.log

#==============================================================================
# Targets
#==============================================================================

# Default target
all: compile run

# Target to compile the testbench and DUT
compile:
	@echo "================================================================="
	@echo " COMPILING DUT AND TESTBENCH..."
	@echo "================================================================="
	$(COMPILER) $(COMPILE_FLAGS) $(INCLUDE_DIRS) $(DUT_FILES) $(TB_TOP_FILE) -l compile.log

# Target to run the simulation
run:
	@echo "================================================================="
	@echo " RUNNING TEST: $(TESTNAME)"
	@echo "================================================================="
	./simv $(RUN_FLAGS)

# Target to clean up the directory
clean:
	@echo "================================================================="
	@echo " CLEANING UP SIMULATION FILES..."
	@echo "================================================================="
	rm -rf simv* csrc *.log *.vdb ucli.key DVEfiles/ novas.* verdiLog/ *.fsdb

.PHONY: all compile run clean
