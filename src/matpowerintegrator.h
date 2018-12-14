/*
``matpowerintegrator'' represents the collection of functions necessary to implement the right communication
between the distribution simulator/player (Gridlab-D) and the transmission player (MATPOWER)
==========================================================================================
Copyright (C) 2018, Battelle Memorial Institute
Written by: 
  Laurentiu Dan Marinovici, Pacific Northwest National Laboratory
  Jacob Hansen, Pacific Northwest National Laboratory
  Gayathri Krishnamoorthy, Pacific Northwest National Laboratory

==========================================================================================
*/

#include "helics/helics.hpp"
#include <stdio.h>
#include <stdlib.h>
#include <iostream>
#include <fstream>
#include <sstream>
#include <algorithm> // for the transform function
#include <cmath> // (math.h) for the absolute value
#include <complex>
using namespace std;
#include <string.h>

#define PI 3.14159265

#ifdef _WIN32
  #include <Windows.h>
#else
  #include <sys/time.h> // for Unix time/POSIX time/epoch time
  #include <ctime>
#endif

void getpower(std::unique_ptr<helics::ValueFederate> &fed, helics::Input lookupId, int *has, double *real, double *imag);
void getDispLoad(std::unique_ptr<helics::ValueFederate> &fed, helics::Input lookupId, double *maxDispLoad);
void getDLDemandCurve(std::unique_ptr<helics::ValueFederate> &fed, helics::Input lookupId, double *c2, double *c1, double *c0);
void getUnrespLoad(std::unique_ptr<helics::ValueFederate> &fed, helics::Input lookupId, double *unrespLoad);
string delSpace(string complexValue);
