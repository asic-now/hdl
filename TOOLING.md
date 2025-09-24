# Tooling

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

This section was written for Altair DSim v2025.1.

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

#### DSim DPI-C

Most verification models are implemented with C reference functions. C functions are called from UVM testbench model using DPI-C.

* <https://help.metrics.ca/support/solutions/articles/154000141123-how-to-integrate-c-c-files-with-your-design>
* <https://help.metrics.ca/support/solutions/articles/154000141203-user-guide-dsim-using-the-dpi-and-pli>

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

## VSCode Integration

### DSim Studio

See [Altair DSim](#altair-dsim) section.

### TerosHDL

1. Python3 should be installed.
2. Install required python packages `pip install -r requirements.txt`.
3. `make` should be installed. It is part of git bash on Windows and comes standard on Linux and macOS.
4. Install [Xilinx Vivado](#xilinx-vivado-recommended-for-uvm).  
   Make sure `vivado` is added to the PATH, run `which vivado` in bash or `where vivado.bat` in Windows CMD to check.  
   If vivado is not found, add Vivado installation to PATH environment variable.
5. Install [TerosHDL extension](https://marketplace.visualstudio.com/items?itemName=teros-technology.teroshdl)
6. Configure TerosHDL
   1. Open VSCode and select the TerosHDL icon on the sidebar.
   2. Go to "Configuration" section and choose "Open Global Settings Menu".
   3. Under "Linter settings", select "Vivado" to enable Vivado as code checker.
   4. Under "Tools," set the default synthesis/simulation tool to Vivado.
   5. Under "Tools" > "Vivado", enter path to `vivado` executable (`vivado.exe` on Windows). (Even if it is added to PATH environemtn variable, TerosHDL might be unable to find it.)
7. Use the "Verify Setup" command in the TerosHDL sidebar to check configuration and tool detection. Review Output > TerosHDL: Global log and correct any missing tools.  
Note: "Verify Setup" can be tricky to troubleshoot - make sure project setup does not inadvertently override global Vivado path setting (see [vscode-terosHDL#778](https://github.com/TerosTechnology/vscode-terosHDL/issues/778)).
