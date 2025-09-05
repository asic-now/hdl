# Makefile for compiling and running the UVM testbench using Xilinx Vivado.
#
# Assumes this Makefile is in the project root, with 'rtl/' and 'verif/' subdirectories.
# Before running, ensure you have sourced the Vivado settings script
# (e.g., `source /tools/Xilinx/Vivado/2023.2/settings64.sh`).
#
# Usage:
#   make compile      - Compiles and elaborates the DUT and testbench.
#   make run          - Runs the default test (fp16_add_random_test).
#   make run TESTNAME=<test_class_name> - Runs a specific test.
#   make all          - Compiles and runs the default test.
#   make clean        - Removes all generated simulation files.
#

#==============================================================================
# Variables
#==============================================================================

# Vivado Simulator Commands
VLOG        = xvlog
ELAB        = xelab
SIM         = xsim

# Default test to run if not specified on the command line
TESTNAME ?= fp16_add_random_test

# Simulation Snapshot Name
SNAPSHOT = tb_top_snapshot

# Project Structure
RTL_DIR      = rtl/verilog/fp16
TEST_DIR     = verif/tests/fp16_add
VERIF_LIB_DIR= verif/lib

# Source Files
DUT_FILES    = $(RTL_DIR)/fp16_add.v
SV_FILES     = $(wildcard $(TEST_DIR)/*.sv) $(wildcard $(VERIF_LIB_DIR)/*.sv)
TB_TOP_NAME  = fp16_add_tb_top

# Include paths for the compiler
INCLUDE_DIRS = -i $(VERIF_LIB_DIR) -i $(TEST_DIR)

# Compilation Flags
# --sv        : Enable SystemVerilog
VLOG_FLAGS = --sv $(INCLUDE_DIRS)

# Elaboration Flags
# --snapshot  : The name of the output snapshot
# --debug all : Enable full debugging capabilities
# -L uvm      : Link the precompiled UVM library
ELAB_FLAGS = --snapshot $(SNAPSHOT) --debug all -L uvm

# Runtime Flags
# -R          : Run simulation immediately (batch mode)
# --sv_plusargs : Pass plusargs to the simulation
RUN_FLAGS = --runall --sv_plusargs "+UVM_TESTNAME=$(TESTNAME)"

#==============================================================================
# Targets
#==============================================================================

# Default target
all: compile run

# Target to compile and elaborate the design
compile:
	@echo "================================================================="
	@echo " COMPILING AND ELABORATING FOR VIVADO SIMULATOR..."
	@echo "================================================================="
	$(VLOG) $(VLOG_FLAGS) $(DUT_FILES) $(SV_FILES)
	$(ELAB) $(ELAB_FLAGS) $(TB_TOP_NAME)

# Target to run the simulation
run:
	@echo "================================================================="
	@echo " RUNNING TEST: $(TESTNAME)"
	@echo "================================================================="
	$(SIM) $(SNAPSHOT) $(RUN_FLAGS)

# Target to clean up the directory
clean:
	@echo "================================================================="
	@echo " CLEANING UP SIMULATION FILES..."
	@echo "================================================================="
	rm -rf xsim.dir/ .Xil/ xelab.* xvlog.* *.log *.jou webtalk*

.PHONY: all compile run clean

