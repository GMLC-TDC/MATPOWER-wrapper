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
   - read_model_dim function reads the file that has the transmission system model, just to get the dimensions of the models, such that we can later create the matrices without need of dynamic allocation
   - nbrows, nbcolumns = number of rows and columns for the bus matrix (mpc.bus)
   - ngrows, ngcolumns = number of rows and columns for generator matrix (mpc.gen)
   - nbrrows, nbrcolumns = number of rows and columns for branch matrix (mpc.branch)
   - narows, nacolumns = number of rows and columns for area matrix (mpc.areas)
   - ncrows, nccolumns = number of rows and columns for the generator cost matrix (mpc.gencost)
   - noffGen = number of generators
   - nHELICSBus = number of buses that have feeders attached
   - nHELICSFeeders = number of feeders attached
   
*/

void read_model_dim(char *file_name, int *nbrows, int *nbcolumns, int *ngrows, int *ngcolumns,
              int *nbrrows, int *nbrcolumns, int *narows, int *nacolumns,
              int *ncrows, int *nccolumns, int *nHELICSBus, int *nHELICSFeeders, int *noffGen)
{
// Open the file with the name given by the file name
ifstream data_file(file_name, ios::in);
string curr_line; // string holding the line that I scurrently read
if (data_file.is_open()) {
   LDEBUG << "======== Starting reading the data file, to get the transmission model size. ======" ;
   while (data_file.good()) { // this will test the EOF mark
      // data_file >> ws;
      getline(data_file, curr_line);
      if (curr_line[0] != '%') {
         // ================== READING BUS DATA SIZE =========================================
         if (strncmp(&curr_line[0], "mpc.busData =", 13) == 0) {
            LDEBUG << "Reading BUS DATA SIZE ...................." ;
            sscanf(&curr_line[0], "%*s = [ %d %d %*s", nbrows, nbcolumns);
         }
         // ================== READING BRANCH DATA SIZE =========================================
         if (strncmp(&curr_line[0], "mpc.branchData =", 16) == 0) {
            LDEBUG << "Reading BRANCH DATA SIZE ...................." ;
            sscanf(&curr_line[0], "%*s = [ %d %d %*s", nbrrows, nbrcolumns);
         }
         // ================== READING GENERATOR DATA SIZE =========================================              
         if (strncmp(&curr_line[0], "mpc.genData =", 13) == 0) {
            LDEBUG << "Reading GENERATOR DATA ...................." ;
            sscanf(&curr_line[0], "%*s = [ %d %d %*s", ngrows, ngcolumns);
         }
         // ================== READING AREAS DATA SIZE =========================================              
         if (strncmp(&curr_line[0], "mpc.areaData =", 14) == 0) {
            LDEBUG << "Reading AREAS DATA SIZE ...................." ;
            sscanf(&curr_line[0], "%*s = [ %d %d %*s", narows, nacolumns);
         }
         // ================== READING GENERATOR COST DATA =========================================              
         if (strncmp(&curr_line[0], "mpc.gencostData =", 14) == 0) {
            LDEBUG << "Reading GENERATOR COST DATA SIZE ...................." ;
            sscanf(&curr_line[0], "%*s = [ %d %d %*s", ncrows, nccolumns);
         }
         // ================== READING NUMBER OF BUSES WHERE SUBSTATION ARE CONNECTED FOR HELICS COMMUNICATION =========================================              
         if (strncmp(&curr_line[0], "mpc.BusCoSimNum =", 17) == 0) {
            LDEBUG << "Reading HELICS BUS NUMBER ...................." ;
            sscanf(&curr_line[0], "%*s = %d %*s", nHELICSBus);
         }
         // ================== READING NUMBER OF POSSIBLE OFF-LINE GENERATORS FOR HELICS COMMUNICATION =========================================              
         if (strncmp(&curr_line[0], "mpc.offlineGenNum =", 19) == 0) {
            LDEBUG << "Reading OFFLINE GENERATOR NUMBER  ...................." ;
            sscanf(&curr_line[0], "%*s = %d %*s", noffGen);
         }
         // ================== READING NUMBER OF FEEDERS THAT ARE CONNECTED TO BUSES IN A TRANSMISSION NETWORK ===============================
         if (strncmp(&curr_line[0], "mpc.FeederNumCoSim =", 20) == 0) {
           LDEBUG << "Reading HELICS FEEDER NUMBER ...................................";
           sscanf(&curr_line[0], "%*s = %d %*s", nHELICSFeeders);
         }
      } // END OF if (curr_line[0] != '%')
   } // END OF while (data_file.good())
   LDEBUG << "Reached the end of the file!!!!!!!!" ;
   LDEBUG << "======== Done reading the data file!!!!!!!!! ====================";
   data_file.close(); } // END OF if (data_file.is_open())
else {
   LERROR << "Unable to open file" ;
   data_file.close(); }
} // END OF get_dim function
