/*
==========================================================================================
Copyright (C) 2018, Battelle Memorial Institute
Written by: 
  Laurentiu Dan Marinovici, Pacific Northwest National Laboratory
  Jacob Hansen, Pacific Northwest National Laboratory
  Gayathri Krishnamoorthy, Pacific Northwest National Laboratory

==========================================================================================
*/
#include <stdio.h>
#include <math.h>
#include <iostream>
#include <fstream>
#include <cstdlib>
#include <sstream>
#include <vector>
#include <cstring>
using namespace std;

#include "logging.hpp"


void read_load_profile(char *file_name, vector< vector<double> > &load_profile, int subst_num, int readings_num);
     

void read_model_dim(char *file_name, int *nbrows, int *nbcolumns, int *ngrows, int *ngcolumns,
              int *nbrrows, int *nbrcolumns, int *narows, int *nacolumns,
              int *ncrows, int *nccolumns, int *nHELICSBus, int *nHELICSFeeders, int *noffGen);

void read_model_data(char *file_name, int nbrows, int nbcolumns, int ngrows, int ngcolumns,
              int nbrrows, int nbrcolumns, int narows, int nacolumns,
              int ncrows, int nccolumns, int nHELICSbuses, int nHELICSfeeders, int noffgelem,
              double *baseMVA, vector<double> &bus, vector<double> &gen,
              vector<double> &branch, vector<double> &area, vector<double> &costs, vector<int> &BusHELICS,
              vector<string> &FeederNameHELICS, vector<int> &FeederBusHELICS,
              vector<int> &offline_gen_bus, double *ampFactor);
