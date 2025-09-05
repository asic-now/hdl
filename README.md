# hdl

Hardware Description Language library

This project contains a library of synthesizable Verilog RTL for various floating-point operations, along with a comprehensive UVM-based verification environment.

## **Project Structure**

The repository is organized into two main directories: rtl/ and verif/.

* rtl/verilog/: Contains all synthesizable Verilog source code.  
  * fp16/: Modules for 16-bit (half-precision) floating-point numbers.  
  * fp32/: Modules for 32-bit (single-precision) floating-point numbers.  
  * fp64/: Modules for 64-bit (double-precision) floating-point numbers.  
* verif/: Contains the UVM verification environment.  
  * lib/: Contains generic, reusable UVM base classes and components designed to be shared across different testbenches.  
  * tests/: Contains DUT-specific testbenches. Each subdirectory (e.g., fp16\_add/) is a complete testbench for a single RTL module.

## **Simulator Setup**

The provided verification environment is based on the **Universal Verification Methodology (UVM)**. To run the tests, you must use a simulator that supports SystemVerilog and UVM.

### **Synopsys VCS (Recommended for UVM)**

VCS is a high-performance commercial simulator required for running the UVM testbenches in this project.

* **Installation**: VCS is a licensed product from Synopsys. It is typically installed in a corporate or academic environment. Please follow the installation and environment setup guides provided by your organization or university.  
* **Usage**: The included Makefile was originally configured for VCS. You can run make commands using a version of the Makefile configured for VCS to compile and run the tests.

### **Icarus Verilog (for non-UVM designs)**

Icarus Verilog is an excellent open-source Verilog simulator. However, it **does not support UVM**. It is suitable for running basic, non-UVM SystemVerilog testbenches but will fail to compile the verification environment in this repository.

* **Installation (Linux \- Debian/Ubuntu)**:  
  sudo apt-get update  
  sudo apt-get install iverilog

* **Installation (Linux \- RedHat/CentOS)**:  
  sudo yum install iverilog

* **Installation (macOS via Homebrew)**:  
  brew install icarus-verilog

* Installation (Windows):  
  Pre-compiled binaries are available for download from the official Icarus website: <http://iverilog.icarus.com/>
