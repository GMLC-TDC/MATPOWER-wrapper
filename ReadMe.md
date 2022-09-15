
# Transmission System Solver for Co-Simulation #

****************************************
*Copyright (C) 2018, Battelle Memorial Institute*

****************************************

This repository contains the necessary code in order to simulate Transmission systems that can be used for Co-Simulation with HELICS. This work uses MATPOWER explained below.


**\[DEVELOPERS NOTE\} This repository is based on an older version of HELICS.  It is not currently under development, recent interactions between MATPOWER and HELICS would typically use the HELICS matlab interface and interact more directly rather than compiling a library for interacting with HELICS and matlab.  This code is made available as an example and for future reference if the effort is revived in the future. **


## MATPOWER ##

MATPOWER is a package of MATLAB M-files for solving power flow and optimal power flow problems. To download the package in its latest version or previous ones follow this [link][link2MATPOWER]. The main documentation can be found [here][link2MATPOWERMan] \[1\], while a short description of its functionality is presented in this [paper][link2MATPOWERpaper] \[2\].

The main 3 steps of running a MATPOWER simulation are:
<ol>
  <li>Preparing the input data file known as the case file, which defines all the parameters relevant to the power system in question and the purpose of the problem;</li>
  <li>Invoking the appropriate function to solve the problem;</li>
  <li>Accessing, saving to output files or plotting the simulation results.</li>
</ol>

## MATPOWER case files ##

MATPOWER case files are MATLAB functions (``.m`` files) that specify a set of data matrices corresponding to each component of the studied power system, that is, buses, generators, lines/branches, etc. All these matrices are bundled in a MATLAB structure, referred to as a **M**AT**P**OWER **C**ase (MPC).


# How to Install and Run MATPOWER-wrapper with HELICS #

The MATPOWER-wrapper is supported to work with both MATLAB and OCTAVE and has been currently tested to work in Windows and Linux environments. 
In addition to the wrapper, a demoDSO code is also provided in this repo. The demoDSO is dummy code to emulate ISO-DSO interactions using helics-based cosimulation. 


## Installation guide - MATLAB+Python in Windows ##

     
  1. Requires MATLAB to be installed and discoverable  
  2. Install matHELICS (Installation instructions can be found here: [matHELICS](https://github.com/GMLC-TDC/matHELICS)
  3. Install pyhelics: pip install helics (This will install the python bindings required by the demoDSO)



## Installation guide - Octave+Python in Linux ##

  1. Requires Octave to be installed and added to the path 
  2. Build HELICS from source with Swig-based bindigns for Octave
  
    Building HELICS from Source with Octave 
    1.  Navigate to your Installation Directory  (lets us assume it is /home/user/Software/; change this path as appropriate)
    2.  mkdir helics_install (make the installation directory for HELICS)
    3.  wget https://github.com/GMLC-TDC/HELICS/releases/download/v3.1.1/Helics-v3.1.1-source.tar.gz  (this link downloads the source code for Helics 3.1.1)
    4.  mkdir Helics_Source (Creating a directory for the source code that will be obtained from extracting the tar )
    5.  tar -xvf Helics-v3.1.1-source.tar.gz -C /home/user/Software/Helics_Source/
    6.  cd Helics_Source/
    7.  mkdir build
    8.  cd build/
    9.  export CFLAGS="-Wno-error" (There is an octave-swig compatibility issue, temporary work-around by ingoring format-security checks)
    10. export CXXFLAGS="-Wno-error" (There is an octave-swig compatibility issue, temporary work-around by ingoring format-security checks)
    11. cmake -DHELICS_BUILD_OCTAVE_INTERFACE=ON -DCMAKE_INSTALL_PREFIX=/home/helics-user/Software/helics_install ..`
    12. make -j8
    13. make install
    This will install the HELICS in the specified </home/helics-user/Software/helics_install>
 
  3. Install pyhelics: pip install helics (This will install the python bindings required by the demoDSO)
  
 



## Running guide - Linux ##

To run MATPOWER simulator as part of the HELICS environment in Linux, use the guide above to install the software utility. Currently, the way of starting the simulation is through the command line

```
./start_MATPOWER <helics json> <MATPOWER case file> <real power demand file> <reactive power demand file> <renewable generation> <market time> <market time shift> <starting on> <total simulation time> <load metric file> <generation metric file>
```

Where:

* *`<helics json>`* is the HELICS json configuration file.
* *`<MATPOWER case file>`* is the MATPOWER case file.
* *`<real power demand file>`* is the 5 minutes real load profile data per bus in the MATPOWER case file.
* *`<reactive power demand file>`* is the 5 minutes reactive load profile data per bus in the MATPOWER case file.
* *`<renewable generation>`* is the 5 minutes renewable generation profile per bus in the MATPOWER case file.
* *`<market time>`* is the time delta in seconds between OPF solutions.
* *`<market time shift>`* is the amount of second the OPF cycle needs to be shifted.
* *`<starting on>`* is the date the simulation will start on. Used for the metric files.
* *`<total simulation time>`* is the total simulation time in seconds.
* *`<load metric file>`*  is the file to store the load metric data in.
* *`<generation metric file>`* is the file to store the generation metric data in.

## References ##

\[1\] R. D. Zimmerman, C. E. Murillo-Sanchez, and R. J. Thomas, "*MATPOWER: Steady-State Operations, Planning and Analysis Tools for Power Systems Research and Education*," Power Systems, IEEE Transactions on, vol. 26, no. 1, pp. 12-19, Feb. 2011. Paper can be found [here][link2MATPOWERpaper].

\[2\] R. D. Zimmerman, C. E. Murillo-Sanchez, "*MATPOWER: User's Manual*". Download the manual [here][link2MATPOWERman]

[link2MATPOWER]: http://www.pserc.cornell.edu/matpower/ "MATPOWER site"
[link2MATPOWERMan]: http://www.pserc.cornell.edu/matpower/MATPOWER-manual.pdf "MATPOWER manual"
[link2MATPOWERpaper]: http://www.pserc.cornell.edu/matpower/MATPOWER-paper.pdf "MATPOWER paper"
[linkMCR]: https://www.mathworks.com/products/compiler/mcr.html
[linkHELICS]: https://helics.readthedocs.io/en/latest/installation/index.html


## Release
MATPOWER-wrapper code is distributed under the terms of the BSD-3 clause license. All new
contributions must be made under this license. [LICENSE](LICENSE)

SPDX-License-Identifier: BSD-3-Clause
