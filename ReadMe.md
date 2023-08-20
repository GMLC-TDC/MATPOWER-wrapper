
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
  
 



## Running guide - Linux ## (needs to be updated)

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

# Wrapper Use Guide #

## Architecture Overview ##

Cosimulation: 
Features: 

## Files needed to get started ##
1. json file of system data
2. load data (likely as a .csv)
   Each row of the file gives the number of seconds since the start of the data followed by entries for the load at each bus in MW
3. Any other profile data used in the simulation (wind data will be used as an example)

## Configuring the wrapper ##
Here we will go through an example wrapper configuration file, explaining the various components.


    "matpower_most_data": {
        "datapath": "../system_data/ERCOT/",
        "case_name": "ERCOT_8_system.json",
        "load_profile_info": {}
        "wind_profile_info": {} 
    }
   
This first section sets up the location of the data and gives the file names for the system data and load data. The resolution refers to the time between data points in seconds, in this case 300 seconds, or 5 minutes between data points. The data map clarifies which columns of the load data refer to which buses. In this case, columns 2-9 in the load data refer to buses 1-8.

Load Profile Information:

    "load_profile_info": {
        "filename": "2016_ERCOT_8_system_5min_load_data.csv",
        "resolution": 300,
        "starting_time": "2016-01-01 00:00:00",
        "data_map": {
            "columns": [2, 3, 4, 5, 6, 7, 8, 9],
            "bus": [1, 2, 3, 4, 5, 6, 7, 8]
      }
    }     
    
The wind profile information here works much the same way, with the data map referring to individual generators. In this case, columns 2-35 in the data give the generation in MW for generators 77-110 as labeled in the system data.

Wind Profile Information: 

    "wind_profile_info": {
    	"filename": "2016_ERCOT_5min_wind_data.csv",
    	"resolution": 300,
    	"starting_time": "2016-01-01 00:00:00",
		"data_map": {
			"columns": [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35], 
    		"gen": [77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95, 96, 97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110]
			}
		}


THere is where the simulation specifications begin.

  Where to print results
  "results_files": "../results/", 
  
  What period of time should be simulated (this will simulate August 10-11 of 2016)
  "start_time": "2016-08-10 00:00:00", 
  "end_time": "2016-08-12 00:00:00", 
  
  Here are a few settings for the simulation
  Flags:
  
	"include_contingencies": false, 
	"include_renewable_uncertainty": false,
	"include_load_uncertainty": false,
	"include_reserve_requirements": false,
	"include_line_limits": true,

Which components of the simulation should be included (These settings run both a day-ahead and real-time market, but do not run additional powerflow simulations). THe user can also set wether to use the cosimulation platform HELICS or to provide all necessairy data locally.
  
    "include_physics_powerflow": false,
    "include_real_time_market": true, 
    "include_day_ahead_market": true, 
    "include_helics": false, 
 


  These are the settings for the various components, where type determines the power flow model used, interval determines how often each component is run in seconds. In this case, the power flow is set to run every minute, the day-ahead market runs every 5 minutes, and the day-ahead market runs once per day. The cosimulation bus setting refers to which bus(es) may have a flexible load and the bid model setting refers to the way in which the generator costs are input to the gencost data (see MatPower manual)
    
    "physics_powerflow":{
        "type": "DC",
        "interval": 60,
        "cosimulation_bus": [2]
    }
  
    "real_time_market": {
        "type": "DC",
        "interval": 300, 
        "cosimulation_bus": [2],
        "transactive": true,
        "bid_model": "poly"
    }
    
    "day_ahead_market":{
        "type": "DC",
        "interval": 86400,
        "cosimulation_bus": [2],
        "forecast_error": 10,
        "transactive": true
    }

Here is where the cosimulation settings are given.
    
    "helics_config": {
        "coreType": "zmq",
        "name": "TransmissionSim",
        "period": 1,
        "timeDelta": 0,
        "logfile": "output.log",
        "log_level": "warning",
        "uninterruptible": true
    }


This concludes the wrapper configuration file.

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
