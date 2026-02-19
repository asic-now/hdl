# Makefile for Systolic Array UVM Testbench

COMPILER = vcs
TESTNAME ?= systolic_random_test

# Project Structure
RTL_DIR      = rtl/verilog/systolic
TEST_DIR     = verif/tests/systolic
VERIF_LIB_DIR= verif/lib

# Source Files
# Using filelists is cleaner for complex hierarchies
DUT_FILES    = -F $(TEST_DIR)/filelist.txt

# Include paths
INCLUDE_DIRS = +incdir+$(VERIF_LIB_DIR) +incdir+$(TEST_DIR)

COMPILE_FLAGS = \
	-sverilog \
	-full64 \
	-ntb_opts uvm \
	-debug_access+all \
	-timescale=1ns/1ps \
	-kdb

RUN_FLAGS = \
	+UVM_TESTNAME=$(TESTNAME) \
	-l run.log

all: compile run

compile:
	@echo "================================================================="
	@echo " COMPILING SYSTOLIC TB..."
	@echo "================================================================="
	$(COMPILER) $(COMPILE_FLAGS) $(INCLUDE_DIRS) $(DUT_FILES) -l compile.log

run:
	@echo "================================================================="
	@echo " RUNNING TEST: $(TESTNAME)"
	@echo "================================================================="
	./simv $(RUN_FLAGS)

clean:
	rm -rf simv* csrc *.log *.vdb ucli.key DVEfiles/ novas.* verdiLog/ *.fsdb

.PHONY: all compile run clean