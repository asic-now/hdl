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

### Altair DSim

This section was written with Altair DSim v2025.1.

<https://learn.altair.com/learn/course/getting-started-with-dsim-elearning/table-of-contents/getting-started-with-dsim?page=1>

* **Installation**
  * Register for user account on [www.altairone.com](https://admin.altairone.com/register)
  * Download and install VSCode DSim Studio extension:  
    <https://marketplace.visualstudio.com/items?itemName=AltairEngineering.dsim-studio>
  * In the VSCode primary sidebar select "DSim Studio" extension tab  
  ![DSim](images/vscode_tab_DSim.png)
  * There is an interactive "Installing DSim Walkthrough" that can be opened by clicking `( i )` icon in "DSim Installations" section, which will open in a "Welcome" window.  
  ![DSim](images/vscode_DSim_install.png)
  * Click "Sign in to DSim Cloud..." in "DSim Studio" section.
  * Click "Download" button in "DSim Installations" section.  
  ![DSim](images/vscode_DSim_install.png)
  * Download and install DSim (simulator).
  * Activate installed DSim version in the DSim Studio "DSim Installations" section - right-click on the DSim version to activate it.
  * Activate and download free license on Altair DSim Cloud - click "Manage Free Individual License" icon in "Versions" sub-section of "DSim Installations" section:  
    <https://app.metricsvcloud.com/security/licenses>  
    Make sure to click "Install license using DSim Studio" icon next to the license on the website and follow through to complete the action using VSCode.
    DSim Studio will show check mark "License Activated" next to "Manage Free Individual License" icon in "Versions" sub-section of "DSim Installations" section.
  * Open "DSim Studio" terminal.
  * DSim Studio projects are configured by `*.dpf` files.

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
