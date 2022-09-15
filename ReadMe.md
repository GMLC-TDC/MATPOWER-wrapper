
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

MATPOWER case files are MATLAB functions (``.m`` files) that specify a set of data matrices corresponding to each component of the studied power system, that is, buses, generators, lines/branches, etc. All these matrices are bundled in a MATLAB structure, referred to as a **M**AT**P**OWER **C**ase (MPC). For example, the 9-bus, 3-generator power system model is specified as:

```
function mpc = case9
% CASE9    Power flow data for 9 bus, 3 generator case.
%   Please see CASEFORMAT for details on the case file format.
%
%   Based on data from Joe H. Chow's book, p. 70.

%   MATPOWER
%   $Id: case9.m,v 1.11 2010/03/10 18:08:14 ray Exp $

%% MATPOWER Case Format : Version 2
mpc.version = '2';

%%-----  Power Flow Data  -----%%
%% system MVA base
mpc.baseMVA = 100;

%% bus data
% bus_i type  Pd  Qd  Gs  Bs  area  Vm  Va  baseKV  zone  Vmax  Vmin
mpc.bus = [
1 3 0 0 0 0 1 1 0 345 1 1.1 0.9;
2 2 0 0 0 0 1 1 0 345 1 1.1 0.9;
3 2 0 0 0 0 1 1 0 345 1 1.1 0.9;
4 1 0 0 0 0 1 1 0 345 1 1.1 0.9;
5 1 90  30  0 0 1 1 0 345 1 1.1 0.9;
6 1 0 0 0 0 1 1 0 345 1 1.1 0.9;
7 1 100 35  0 0 1 1 0 345 1 1.1 0.9;
8 1 0 0 0 0 1 1 0 345 1 1.1 0.9;
9 1 125 50  0 0 1 1 0 345 1 1.1 0.9;
];

%% generator data
% bus Pg  Qg  Qmax  Qmin  Vg  mBase status  Pmax  Pmin  Pc1 Pc2 Qc1min  Qc1max  Qc2min  Qc2max  ramp_agc  ramp_10 ramp_30 ramp_q  apf
mpc.gen = [
1 0 0 300 -300  1 100 1 250 10  0 0 0 0 0 0 0 0 0 0 0;
2 163 0 300 -300  1 100 1 300 10  0 0 0 0 0 0 0 0 0 0 0;
3 85  0 300 -300  1 100 1 270 10  0 0 0 0 0 0 0 0 0 0 0;
];

%% branch data
% fbus  tbus  r x b rateA rateB rateC ratio angle status  angmin  angmax
mpc.branch = [
1 4 0 0.0576  0 250 250 250 0 0 1 -360  360;
4 5 0.017 0.092 0.158 250 250 250 0 0 1 -360  360;
5 6 0.039 0.17  0.358 150 150 150 0 0 1 -360  360;
3 6 0 0.0586  0 300 300 300 0 0 1 -360  360;
6 7 0.0119  0.1008  0.209 150 150 150 0 0 1 -360  360;
7 8 0.0085  0.072 0.149 250 250 250 0 0 1 -360  360;
8 2 0 0.0625  0 250 250 250 0 0 1 -360  360;
8 9 0.032 0.161 0.306 250 250 250 0 0 1 -360  360;
9 4 0.01  0.085 0.176 250 250 250 0 0 1 -360  360;
];

%%-----  OPF Data  -----%%
%% area data
% area  refbus
mpc.areas = [
1 5;
];

%% generator cost data
% 1 startup shutdown  n x1  y1  ... xn  yn
% 2 startup shutdown  n c(n-1)  ... c0
mpc.gencost = [
2 1500  0 3 0.11  5 150;
2 2000  0 3 0.085 1.2 600;
2 3000  0 3 0.1225  1 335;
];
```


# How to Install and Run MATPOWER with HELICS #

The 

## Installation guide - MATLAB+Python in Windows ##
     
     

## Installation guide - Octave+Python in Linux ##

In order to be able to integrate MATPOWER under Linux in HELICS, without the need of a MathWorks MATLAB full license, the free MATLAB Runtime (MCR) needs to be installed. All the MCR versions can be downloaded [here][linkMCR]. The installed MCR version needs to be the same as the MATLAB version under which the original MATPOWER code has been compiled in, and built into the deployable files *``libMATPOWER.h``* and *``libMATPOWER.so``* under *``/src``*. for this repository MCR R2018a (9.4) is required. MCR encourages you to add certain paths to the *``LD_LIBRARY_PATH``* on your system. However, as this can cause issues on some system this application does not require you to do so.

To access the MATPOWER functions and pass data back and forth from MATPOWER (transmission, generation, wholesale market simulator) to GridLAB-D (distribution simulator) through HELICS, a C++ wrapper has been written, consisting of:

  * *``src/start_MATPOWER.cpp``* - the main wrapper around the MATPOWER functions that establishes the communication between MATPOWER and HELICS, arranges data according to the type MATLAB requires it or HELICS needs it to make it available to other simulators;
  * *``src/matpowerintegrator.h``* and *``src/matpowerintegrator.cpp``* - define the functions that integrate MATPOWER within the HELICS environment;
  * *``src/read_input_data.h``* - includes all definitions of the functions that read and parse the input data, both the load profile that resides in a text file (created in MATLAB from an experimental set of data meant to model a standard daily load shape) and the MATPOWER model in order to construct the correct C++ counterparts for the matrices needed to solve the power flow;
  * *``src/read_loap_profile.cpp``* - reads in an a-priori built load shape meant to align to a standard daily residential power consumption initialized to the values corresponding to the transmission structure of the MATPOWER model, for the location where distribution models are connected to;
  * *``src/read_model_dim.cpp``* - reads in the MATPOWER model dimensions in order to be able to allocate the correct memory in the C++ wrapper (Observation. I went this route because I found it hard to make it work with dynamic allocation of memory);
  * *``src/read_model_data.cpp``* - reads the actual data that describes the transmission network in MATPOWER;
  * *``CMakeList.txt``* - the cmake process script that dictates the appropriate program files that are to be compiled and linked together, also specifying the paths to MCR and installation (should be modified accordingly)

Lastly you will also need to have HELICS installed on your system. At the moment this repository is compatible with the HELICS 2.0 beta 1 release. Please follow the guides available [here][linkHELICS] to install HELICS.

### Step by step process to install ###

* Ensure that HELICS is mapped to your path environment on your system
* Ensure that MCR is installed on your system
* Ensure you are in the root of this repository
* Execute the following commands:

```
mkdir build
cd build
# if you did not change the default ZMQ or Boost paths
cmake ../ -DCMAKE_INSTALL_PREFIX=<install path> -DMatlab_ROOT_DIR=<MCR path>
# if you did change them use
cmake ../ -DCMAKE_INSTALL_PREFIX=<install path> -DMatlab_ROOT_DIR=<MCR path> -DZeroMQ_ROOT_DIR=<ZMQ path> -DBOOST_ROOT=<boost path>
make
make install  
```

This will install the software in the specified *`<install path>`*.

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
