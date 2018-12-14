/*
==========================================================================================
Copyright (C) 2018, Battelle Memorial Institute
Written by: 
  Laurentiu Dan Marinovici, Pacific Northwest National Laboratory
  Jacob Hansen, Pacific Northwest National Laboratory
  Gayathri Krishnamoorthy, Pacific Northwest National Laboratory

==========================================================================================
*/

#include "read_input_data.h"

/*
   - read_model_data function reads the file that has the transmission system model
   - nbrows, nbcolumns = number of rows and columns for the bus matrix (mpc.bus)
   - ngrows, ngcolumns = number of rows and columns for generator matrix (mpc.gen)
   - nbrrows, nbrcolumns = number of rows and columns for branch matrix (mpc.branch)
   - narows, nacolumns = number of rows and columns for area matrix (mpc.areas)
   - ncrows, nccolumns = number of rows and columns for the generator cost matrix (mpc.gencost)
   - nHELICSbuses = number of buses where distribution neworks are connected to
   - nHELICSfeeders = number of feeders/GridLAB-Ds; more than one distribution network could be connected to the same bus
   - baseMVA = usually 100, but given in the input file (mpc.baseMVA)
   - bus = the BUS matrix
   - gen = the GENERATOR matrix
   - branch = the BRANCH matrix
   - area = the AREA matrix
   - costs = the GENERATOR COSTS matrix
   - FeederBusHELICS = the buses used in HELICS to connect distribution networks to
   - FeederNameHELICS = names of the feeder connected to the transimission buses
   - BusHELICS = corresponding bus number to where each substation is connected to
   - offline_gen_bus = buses of generators that could be turned off to create a possible fault
   - ampFactor = power/load amplification factor

*/

void read_model_data(char *file_name, int nbrows, int nbcolumns, int ngrows, int ngcolumns,
              int nbrrows, int nbrcolumns, int narows, int nacolumns,
              int ncrows, int nccolumns, int nHELICSbuses, int nHELICSfeeders, int noffgelem,
              double *baseMVA, vector<double> &bus, vector<double> &gen,
              vector<double> &branch, vector<double> &area, vector<double> &costs, vector<int> &BusHELICS,
              vector<string> &FeederNameHELICS, vector<int> &FeederBusHELICS,
              vector<int> &offline_gen_bus, double *ampFactor)
{  
// Open the file with the name given by the file name
ifstream data_file(file_name, ios::in);
bool read_bus = 0, read_line = 0, read_gen = 0, read_areas = 0, read_gencost = 0;
bool read_BusHELICS = 0, read_offlineGenBus = 0, read_FeederNameHELICS = 0;
int ind_row, ind_col, ind = 0;
string curr_line; // string holding the line that I scurrently read
if (data_file.is_open()) {
  LDEBUG << "======== Starting reading the data file. ======" ;
  while (data_file.good()) { // this will test the EOF mark
    // data_file >> ws;
    getline(data_file, curr_line);
    if (curr_line[0] != '%') {
      // ================== READING BASE MVA =========================================
      if (strncmp(&curr_line[0], "mpc.baseMVA =", 13) == 0) {
        LDEBUG << "Reading BASE MVA ......................." ;
        sscanf(&curr_line[0], "%*s = %lf %*s", baseMVA);
      }
      // ================== READING BUS DATA =========================================
      if (strncmp(&curr_line[0], "mpc.bus =", 9) == 0) {
        LDEBUG << "Reading BUS DATA ...................." ;
        read_bus = 1;
      }
      if (read_bus == 1 & strncmp(&curr_line[0], "mpc.bus =", 9) != 0) {
        if (ind < nbrows*nbcolumns) {
          read_bus = 1;
          sscanf(&curr_line[0], "%lf %lf %lf %lf %lf %lf %lf %lf %lf %lf %lf %lf %lf %*s", &bus[ind], &bus[ind + 1], &bus[ind + 2], &bus[ind + 3],
                  &bus[ind + 4], &bus[ind + 5], &bus[ind + 6], &bus[ind + 7], &bus[ind + 8],
                  &bus[ind + 9], &bus[ind + 10], &bus[ind + 11], &bus[ind + 12]);
          ind += nbcolumns;
        }
        else {
          read_bus = 0;
          ind = 0;
        }
      }
      // ================== READING BRANCH DATA =========================================
      if (strncmp(&curr_line[0], "mpc.branch =", 12) == 0) {
        LDEBUG << "Reading BRANCH DATA ...................." ;
        read_line = 1;
      }
      if (read_line == 1 & strncmp(&curr_line[0], "mpc.branch =", 12) != 0) {
        if (ind < nbrrows*nbrcolumns) {
          read_line = 1;
          sscanf(&curr_line[0], "%lf %lf %lf %lf %lf %lf %lf %lf %lf %lf %lf %lf %lf %*s", &branch[ind], &branch[ind + 1], &branch[ind + 2], &branch[ind + 3],
                  &branch[ind + 4], &branch[ind + 5], &branch[ind + 6], &branch[ind + 7], &branch[ind + 8],
                  &branch[ind + 9], &branch[ind + 10], &branch[ind + 11], &branch[ind + 12]);
          ind += nbrcolumns;
        }
        else {
          read_line = 0;
          ind = 0;
        }
      }
      // ================== READING GENERATOR DATA =========================================              
      if (strncmp(&curr_line[0], "mpc.gen =", 9) == 0) {
        LDEBUG << "Reading GENERATOR DATA ...................." ;
        read_gen = 1;
      }
      if (read_gen == 1 & strncmp(&curr_line[0], "mpc.gen =", 9) != 0) {
        if (ind < ngrows*ngcolumns){
          read_gen = 1;
          sscanf(&curr_line[0], "%lf %lf %lf %lf %lf %lf %lf %lf %lf %lf %lf %lf %lf %lf %lf %lf %lf %lf %lf %lf %lf %*s", &gen[ind], &gen[ind + 1],
                  &gen[ind + 2], &gen[ind + 3], &gen[ind + 4], &gen[ind + 5], &gen[ind + 6], &gen[ind + 7], &gen[ind + 8],
                  &gen[ind + 9], &gen[ind + 10], &gen[ind + 11], &gen[ind + 12], &gen[ind + 13], &gen[ind + 14],
                  &gen[ind + 15], &gen[ind + 16], &gen[ind + 17], &gen[ind + 18], &gen[ind + 19], &gen[ind + 20]);
          ind += ngcolumns; 
        }
        else {
          read_gen = 0;
          ind = 0;
        }
      }
      // ================== READING AREAS DATA =========================================              
      if (strncmp(&curr_line[0], "mpc.areas =", 11) == 0) {
        LDEBUG << "Reading AREAS DATA ...................." ;
        read_areas = 1; }
      if (read_areas == 1 & strncmp(&curr_line[0], "mpc.areas =", 11) != 0){
        if (ind < narows*nacolumns){
          read_areas = 1;
          sscanf(&curr_line[0], "%lf %lf %*s", &area[ind], &area[ind + 1]);
          ind += nccolumns;
        }
        else {
          read_areas = 0;
          ind = 0;
        }
      }
      // ================== READING GENERATOR COST DATA =========================================              
      if (strncmp(&curr_line[0], "mpc.gencost =", 13) == 0) {
        LDEBUG << "Reading GENERATOR COST DATA ...................." ;
        read_gencost = 1; }
      if (read_gencost == 1 & strncmp(&curr_line[0], "mpc.gencost =", 13) != 0){
        if (ind < ncrows*nccolumns){
          read_gencost = 1;
          sscanf(&curr_line[0], "%lf %lf %lf %lf %lf %lf %lf %*s", &costs[ind], &costs[ind + 1], &costs[ind + 2], &costs[ind + 3],
                  &costs[ind + 4], &costs[ind + 5], &costs[ind + 6]);
          ind += nccolumns;
        }
        else {
          read_gencost = 0;
          ind = 0;
        }
      }
      // ================== READING BUS NUMBERS FOR HELICS COMMUNICATION =========================================              
      if (strncmp(&curr_line[0], "mpc.BusCoSim =", 14) == 0) {
        LDEBUG << "Reading HELICS SUBSTATION BUSES ...................." ;
        read_BusHELICS = 1; }
      if (read_BusHELICS == 1 & strncmp(&curr_line[0], "mpc.BusCoSim =", 14) != 0){
        if (ind < nHELICSbuses){
          read_BusHELICS = 1;
          sscanf(&curr_line[0], "%d %*s", &BusHELICS[ind]);
          ind += 1;
        }
        else {
          read_BusHELICS = 0;
          ind = 0;
        }
      }
      // ================== READING FEEDER NAMES FOR HELICS COMMUNICATION - T&D level =========================================              
      if (strncmp(&curr_line[0], "mpc.FeederNameCoSim =", 21) == 0) {
        LDEBUG << "Reading HELICS FEEDER NAMES ...................." ;
        read_FeederNameHELICS = 1; }
      if (read_FeederNameHELICS == 1 & strncmp(&curr_line[0], "mpc.FeederNameCoSim =", 21) != 0){
        if (ind < nHELICSfeeders){
          read_FeederNameHELICS = 1;
          char temp[50];
          sscanf(&curr_line[0], "%s %d %*s", temp, &FeederBusHELICS[ind]);
          FeederNameHELICS[ind] = temp;
          ind += 1;
        }
        else {
          read_FeederNameHELICS = 0;
          ind = 0;
        }
      }
      // ================== READING BUS NUMBERS FOR POSSIBLE OFF-LINE GENERATORS FOR HELICS COMMUNICATION =========================================              
      if (strncmp(&curr_line[0], "mpc.offlineGenBus =", 19) == 0) {
        LDEBUG << "Reading OFFLINE GENERATOR BUSES ...................." ;
        read_offlineGenBus = 1; }
      if (read_offlineGenBus == 1 & strncmp(&curr_line[0], "mpc.offlineGenBus =", 19) != 0){
        if (ind < noffgelem){
          read_offlineGenBus = 1;
          sscanf(&curr_line[0], "%d %*s", &offline_gen_bus[ind]); // go with only 1 generator switching off-line
          ind += 1;
        }
        else {
          read_offlineGenBus = 0;
          ind = 0;
        }
      }
      // =================== READING THE AMPLIFICATION FACTOR USED TO SIMULATE A HIGHER LOAD AT THE FEEDER ======================================
      if (strncmp(&curr_line[0], "mpc.ampFactor =", 15) == 0) {
        LDEBUG << "Reading the AMPLIFICATION FACTOR FOR THE FEEDER ..........................." ;
        sscanf(&curr_line[0], "%*s = %lf %*s", ampFactor);
      }
    } // END OF if (curr_line[0] != '%')
  } // END OF while (data_file.good())
  LDEBUG << "Reached the end of the file!!!!!!!!" ;
  LDEBUG << "======== Done reading the data file!!!!!!!!! ====================" ;
  data_file.close(); } // END OF if (data_file.is_open())
else {
  LERROR << "Unable to open file" ;
  data_file.close(); }
} // END OF get_data function
