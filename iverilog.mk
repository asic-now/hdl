# Makefile for compiling and running the testbench.
#
# NOTE: This Makefile is configured for Icarus Verilog (`iverilog`).
# The current testbench is UVM-based. Icarus Verilog does NOT support UVM
# out of the box. This Makefile will fail. To run the UVM testbench,
# you must use a UVM-compliant simulator like Synopsys VCS, Cadence Xcelium,
# or Mentor Questa. This file is provided as a template for a non-UVM
# SystemVerilog testbench.
#
# Assumes this Makefile is in the project root, with 'rtl/' and 'verif/' subdirectories.
#
# Usage:
#   make compile      - Compiles the DUT and testbench.
#   make run          - Runs the simulation.
#   make all          - Compiles and runs the simulation.
#   make clean        - Removes all generated simulation files.
#

#==============================================================================
# Variables
#==============================================================================

# Simulator command for Icarus Verilog
COMPILER    = iverilog
SIMULATOR   = vvp

# Output file from the compiler
SIM_OUTPUT  = sim.vvp

# Project Structure
RTL_DIR      = rtl/verilog/fp16
TEST_DIR     = verif/tests/fp16_add
VERIF_LIB_DIR= verif/lib

# Source Files
# For Icarus, it's often more reliable to list all SV files explicitly.
DUT_FILES    = $(RTL_DIR)/fp16_add.v
TB_SRC_FILES = $(wildcard $(TEST_DIR)/*.sv) $(wildcard $(VERIF_LIB_DIR)/*.sv)

# Include paths for the compiler
INCLUDE_DIRS = -I $(VERIF_LIB_DIR) -I $(TEST_DIR)

# Compilation Flags for Icarus Verilog
# -g2012 : Enable SystemVerilog support
# -o     : Specify the output file
COMPILE_FLAGS = \
	-g2012 \
	-o $(SIM_OUTPUT)

# Runtime Flags (Icarus doesn't use +UVM_TESTNAME)
RUN_FLAGS =

#==============================================================================
# Targets
#==============================================================================

# Default target
all: compile run

# Target to compile the testbench and DUT
compile:
	@echo "================================================================="
	@echo " COMPILING DUT AND TESTBENCH (USING iverilog)..."
	@echo " WARNING: UVM testbench will fail to compile with iverilog."
	@echo "================================================================="
	$(COMPILER) $(COMPILE_FLAGS) $(INCLUDE_DIRS) $(DUT_FILES) $(TB_SRC_FILES)

# Target to run the simulation
run:
	@echo "================================================================="
	@echo " RUNNING SIMULATION..."
	@echo "================================================================="
	$(SIMULATOR) $(SIM_OUTPUT) $(RUN_FLAGS)

# Target to clean up the directory
clean:
	@echo "================================================================="
	@echo " CLEANING UP SIMULATION FILES..."
	@echo "================================================================="
	rm -rf $(SIM_OUTPUT) *.log *.vcd

.PHONY: all compile run clean
