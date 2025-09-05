# hdl

Hardware Description Language library

This project contains a library of synthesizable Verilog RTL for various floating-point operations, along with a comprehensive UVM-based verification environment.

## Project Structure

The repository is organized into two main directories: rtl/ and verif/.

* rtl/verilog/: Contains all synthesizable Verilog source code.  
  * fp16/: Modules for 16-bit (half-precision) floating-point numbers.  
  * fp32/: Modules for 32-bit (single-precision) floating-point numbers.  
  * fp64/: Modules for 64-bit (double-precision) floating-point numbers.  
* verif/: Contains the UVM verification environment.  
  * lib/: Contains generic, reusable UVM base classes and components designed to be shared across different testbenches.  
  * tests/: Contains DUT-specific testbenches. Each subdirectory (e.g., fp16\_add/) is a complete testbench for a single RTL module.

## Simulator Setup

The provided verification environment is based on the **Universal Verification Methodology (UVM)**. To run the tests, you must use a simulator that supports SystemVerilog and UVM.

### Xilinx Vivado (Recommended for UVM)

The Vivado Design Suite from AMD/Xilinx includes a UVM-compliant simulator (xsim) that is fully capable of running the testbenches in this project. A free version (Vivado ML Edition) is available.

* **Installation**:  
  1. Go to the official AMD/Xilinx downloads page: [https://www.xilinx.com/support/download.html](https://www.xilinx.com/support/download.html)  
  2. Download the **Vivado ML Edition** installer for your operating system.  
  3. During installation, you can deselect the device families to save space, but ensure the **Verification \-\> Vivado Simulator** component is selected.  
* **Environment Setup**: Before running make, you must source the setup script to add the Vivado tools to your path.  
  * On Linux: source /path/to/Xilinx/Vivado/2023.2/settings64.sh  
  * On Windows: Run the Vivado command prompt, or execute the settings64.bat script.

### Synopsys VCS

VCS is a high-performance commercial simulator.

* **Installation**: VCS is a licensed product from Synopsys. It is typically installed in a corporate or academic environment. Please follow the installation and environment setup guides provided by your organization or university.
* **Usage**: The included Makefile.vcs is configured for VCS. You can run make commands using Makefile.vcs to compile and run the tests using VCS.

### Icarus Verilog (for non-UVM designs)

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
