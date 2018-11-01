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

#include "matpowerintegrator.h"

// See details about GETPOWER in this file preamble
void getpower(helics::ValueFederate *fed, helics::input_id_t lookupId, int *has, double *real, double *imag)
{
  complex<double> lookupKval;
  lookupKval = fed->getValue<complex<double>>(lookupId); // get the power value from the corresponding global key published by GLD

  *has = 1; // message found

  *real = std::real(lookupKval)/1e6;
  *imag = std::imag(lookupKval)/1e6;

  // TODO: We should probably consider doing some smarter unit conversion here
}

void getDispLoad(helics::ValueFederate *fed, helics::input_id_t lookupId, double *maxDispLoad)
{
  *maxDispLoad = fed->getValue<double>(lookupId);
}

void getDLDemandCurve(helics::ValueFederate *fed, helics::input_id_t lookupId, double *c2, double *c1, double *c0)
{
  string lookupKval;
  // get the demand curve for the dispatchable load, if exists, from the corresponding global key published by the "aggregator"
  lookupKval = fed->getValue<string>(lookupId);

  if (!lookupKval.empty())
  {
    lookupKval = delSpace(lookupKval);
    sscanf(&lookupKval[0], "%lf,%lf,%lf", c2, c1, c0); // parse the comma separated vector of coefficients
  }
  else
  {
    c0 = 0;
    c1 = 0;
    c2 = 0;
  }
}

void getUnrespLoad(helics::ValueFederate *fed, helics::input_id_t lookupId, double *unrespLoad)
{
  *unrespLoad = fed->getValue<double>(lookupId);
}

string delSpace (string complexValue)
{
  int i = 0;
  do
  {
    if (isspace(complexValue[i]))
    {
      complexValue.erase(i, 1);
      complexValue = delSpace(complexValue);
    }
    i += 1;
  }
  while (i < complexValue.length());
  return complexValue;
}