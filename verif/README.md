# Verification Environment Structure

This directory contains the UVM-based verification environment for the floating-point RTL library.

## Directory Structure

The environment is split into two key areas to promote code reuse and maintainability.

* lib/: This directory contains generic, reusable UVM components that form the foundation of the verification library.  
  * **Purpose**: To provide base classes (e.g., for transactions, scoreboards, and models) that can be extended by specific testbenches.  
  * **Contents**: Parameterized or abstract base classes that are not tied to any single DUT.  
* tests/: This directory contains the complete, self-contained testbenches for each specific DUT in the rtl/ directory.  
  * **Purpose**: To verify a single RTL module.  
  * **Contents**: Each subdirectory (e.g., fp16\_add/) contains all the necessary components for a testbench, including a DUT-specific transaction, driver, monitor, sequences, and environment, many of which extend the base classes found in lib/.
