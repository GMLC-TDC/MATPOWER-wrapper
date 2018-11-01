/*
==========================================================================================
Copyright (C) 2018, Battelle Memorial Institute
Written by: 
  Laurentiu Dan Marinovici, Pacific Northwest National Laboratory
  Jacob Hansen, Pacific Northwest National Laboratory
  Gayathri Krishnamoorthy, Pacific Northwest National Laboratory

==========================================================================================
*/

#include <helics/application_api/ValueFederate.hpp>
#include <helics/application_api/queryFunctions.hpp>
#include <thread>
#include <stdio.h>
#include <sys/resource.h>
#include <math.h>
#include <iostream>
#include <fstream>
#include <cstdlib>
#include <sstream>
#include <vector>
#include <string.h>
#include <map>
#include <iterator>
#include "libMATPOWER.h"
#include "mclmcrrt.h"
#include "mclcppclass.h"
#include "matrix.h"
#include "logging.hpp"
# define PI 3.14159265
#include "read_input_data.h"
#include "matpowerLoadMetrics.h"
#include "matpowerGeneratorMetrics.h"
#include "matpowerintegrator.h"
#include "json/json.h"

using namespace std;

// set the definition for the logger
loglevel_e loglevel;

std::map<std::string, double> mapOfTimes;
std::map<std::string, double> mapOfClock;

// Transposing matrices; we need this function becuase the way the file reading is done leads to the transpose of the necessary matrix
// Careful: it is 1-base indexing because we are working with MATLAB type array mwArray
mwArray mwArrayTranspose(int nrows, int ncolumns, mwArray matrix_in) {
	mwArray matrix_out(nrows, ncolumns, mxDOUBLE_CLASS);
	for (int ind_row = 1; ind_row <= nrows; ind_row++) {
		for (int ind_col = 1; ind_col <= ncolumns; ind_col++) {
			matrix_out(ind_row, ind_col) = matrix_in(ind_col, ind_row);
		}
	}
	return matrix_out;
}

// function to track where time is spent in this wrapper
void execution_time(time_t &tBefore, clock_t &cBefore, const char *executionDesc) {
	if (loglevel < logMACTIME) {
		return;
	}
	time_t tAfter = time(NULL);
	double tElapsed = difftime(tAfter, tBefore);
	clock_t cAfter = clock();
	double cElapsed = (double)(cAfter - cBefore);

	if (mapOfTimes.find(executionDesc) == mapOfTimes.end()) {
		mapOfTimes.insert(std::make_pair(executionDesc, tElapsed + (cElapsed / CLOCKS_PER_SEC)));
		mapOfClock.insert(std::make_pair(executionDesc, cElapsed));
	}
	else {
		mapOfTimes[executionDesc] = tElapsed + (cElapsed / CLOCKS_PER_SEC) + mapOfTimes[executionDesc];
		mapOfClock[executionDesc] = cElapsed + mapOfClock[executionDesc];
	}
	//LMACTIME << executionDesc << mapOfTimes[executionDesc] << " seconds (time)";
	//LMACTIME << executionDesc << mapOfClock[executionDesc]/CLOCKS_PER_SEC << " seconds (clock)";

	tBefore = time(NULL);
	cBefore = clock();
}


int run_main(int argc, char **argv) {
	// portion to initialize HELICS
  	LINFO << "Initializing HELICS federate";
  	// configuration file for federate
  	std::string configString = argv[1];
  	auto fed = new helics::ValueFederate (configString); 

	const char *options[] = {"-nojvm","-nodisplay"};
	if (!mclInitializeApplication(options, 2)) {
		LERROR << "Could not initialize the application properly !!!";
		return -1;
	}
	if (!libMATPOWERInitialize()) {
		LERROR << "Could not initialize one or more MATLAB/MATPOWER libraries properly !!!";
		return -1;
	}
	else {
		try {
			// ================================ VARIABLE DECLARATION AND INITIALIZATION =============================================
			LINFO << "Just entered the MAIN function of the driver application." ;
			// Initialize the input parameters giving the MATPOWER model file, the load profile, simulation stop time, market clearing time, and JSON files.
			bool withTE;
			if (argc == 13) {
				withTE = true; // boolean flag to choose whether we go as a TE scenarion or a simple T&D
			} else {
				withTE = false;
			}      
			char *file_name;
			file_name = argv[2];
			char *real_load_profile_file;
			real_load_profile_file = argv[3];
			char *reac_load_profile_file;
			reac_load_profile_file = argv[4];
			char *rer_generation_file;
			rer_generation_file = argv[5];
			int simStopTime;
			sscanf(argv[6], "%d%*s", &simStopTime);
			int marketTime;
			sscanf(argv[7], "%d%*s", &marketTime);
			int wholesaleTimeShift;
			sscanf(argv[8], "%d%*s", &wholesaleTimeShift);
			string startTime;
			startTime = argv[9];
			LINFO << "Running MATPOWER ends after " << simStopTime << " seconds, supposing it starts on " << startTime << ".";
      
			// ================================ METRICS FOR TRANSACTIVE ENERGY VALUATION ============================================
			// ================================ LOAD BUS METRICS ====================================================================
			const char *loadMetricsFile;
			loadMetricsFile = argv[10];
			ofstream loadMetricsOutput(loadMetricsFile, ofstream::out);
			loadBusMetrics mpLoadMetrics;
			loadMetadata mpLoadMetadata;
			loadBusValues mpLoadBusValues;
			mpLoadMetrics.setMetadata(mpLoadMetadata);
			mpLoadMetrics.setName(file_name);
			mpLoadMetrics.setStartTime(startTime);
			// ================================ GENERATOR BUS METRICS ================================================================
			const char *generatorMetricsFile;
			generatorMetricsFile = argv[11];
			ofstream generatorMetricsOutput(generatorMetricsFile, ofstream::out);
			generatorBusMetrics mpGeneratorMetrics;
			generatorMetadata mpGeneratorMetadata;
			generatorBusValues mpGeneratorBusValues;
			mpGeneratorMetrics.setMetadata(mpGeneratorMetadata);
			mpGeneratorMetrics.setName(file_name);
			mpGeneratorMetrics.setStartTime(startTime);
			// ================================ DISPATCHABLE LOAD BUS METRICS ================================================================
			const char *dispLoadMetricsFile;
			generatorBusMetrics mpDispLoadMetrics;
			generatorMetadata mpDispLoadMetadata;
			generatorBusValues mpDispLoadValues;
			if (withTE) {
				dispLoadMetricsFile = argv[12];
				ofstream dispLoadMetricsOutput(dispLoadMetricsFile, ofstream::out);
				mpDispLoadMetrics.setMetadata(mpDispLoadMetadata);
				mpDispLoadMetrics.setName(file_name);
				mpDispLoadMetrics.setStartTime(startTime);
			}
			// ======================================================================================================================
			// Read the MATPOWER transmission model file in order to get the size of the system, that is number of busses, generators, etc.
			// These dimensions are needed to be able to create the model matrices later without dynamic allocation of memory.
			// Declaration of dimension variables.
			int nbrows = 0, nbcolumns = 0, ngrows = 0, ngcolumns = 0;
			int nbrrows = 0, nbrcolumns = 0, narows = 0, nacolumns = 0;
			int ncrows = 0, nccolumns = 0, nHELICSbuses = 0, noffgelem = 0, nHELICSfeeders = 0;
			
			// allows us to track time 
			time_t tBefore = time(NULL);
			clock_t cBefore = clock();

			// reads the model dimensions
			read_model_dim(file_name, &nbrows, &nbcolumns, &ngrows, &ngcolumns,
				&nbrrows, &nbrcolumns, &narows, &nacolumns,
				&ncrows, &nccolumns, &nHELICSbuses, &nHELICSfeeders, &noffgelem);

			execution_time(tBefore, cBefore, "Reading MPC structure dimensions took  ");
			/*
			cout << nbrows << '\t' << nbcolumns << '\t' << ngrows << '\t' << ngcolumns << '\t' << endl;
			cout << nbrrows << '\t' << nbrcolumns << '\t' << narows << '\t' << nacolumns << endl;
			cout << ncrows << '\t' << nccolumns << '\t' << nHELICSbuses << '\t' << noffGen << endl;
			*/
			
			// ========================================================================================================================
			// Load profile for the "static" load at all the buses.
			// The number of profiles should be equal to exactly the amount of buses in the system. Careful, though!!!
			// Each profile needs to start from the value that exists initially in the MATPOWER model at the specific bus.
			// Each profile consists of data for 24 hours every 5 minutes (288 values taken repeatedly every day)

			int readings = 288;
			vector< vector<double> > real_power_demand(nbrows, vector<double>(readings));
			vector< vector<double> > reactive_power_demand(nbrows, vector<double>(readings));
			vector< vector<double> > renewable_generation(ngrows, vector<double>(readings));
			for (int i = 0; i < nbrows; i++) {
				for (int j = 0; j < readings; j++) {
					real_power_demand[i][j] = 0;
					reactive_power_demand[i][j] = 0;
				}
			}
			for (int i = 0; i < ngrows; i++) {
				for (int j = 0; j < readings; j++) {
					renewable_generation[i][j] = 0;
				}
			}

			execution_time(tBefore, cBefore, "Initalize MPC structure dimensions took ");

			// Get load profile data, to make the load evolution in time more realistic
			read_load_profile(real_load_profile_file, real_power_demand, nbrows, readings);
			execution_time(tBefore, cBefore, "Reading the real load profile took ");

			read_load_profile(reac_load_profile_file, reactive_power_demand, nbrows, readings);
			execution_time(tBefore, cBefore, "Reading the reactive load profile took ");

			read_load_profile(rer_generation_file, renewable_generation, ngrows, readings);
			execution_time(tBefore, cBefore, "Reading the renewable generation profile took ");

			// Printing out the values just for the sake of testing. Uncomment the portion below if need be.
			/*
			for (int i = 0; i < nbrows; i++) {
				for (int j = 0; j < readings; j++) {
					cout << real_power_demand[i][j] << " ";
				}
				cout << endl;
			}
			*/
			// ========================================================================================================================
			// Rest of the variables declaration

			double baseMVA, nomfreq;
			double amp_fact; // amplification factor for the controlable load.
			// The powerflow solution is going to be calculated in the following variables
			mwArray mwMVAbase, mwBusOut, mwGenOut, mwBranchOut, f, success, info, et, g, jac, xr, pimul, mwGenCost;
			mwArray mwdeltaLoad(1, 1, mxDOUBLE_CLASS);
			double prevTotalLoad = -1;
			double totalLoad = 0;
			mwdeltaLoad = 0.0;

			// Results from RUNPF or RUNOPF will be saved as in MATLAB in a mat file, and printed in a nice form in a file
			// JH: Changing this as these results are only needed for debug and the slow down the calculations
			//mwArray printed_results(mwArray("printed_results.txt"));
			//mwArray saved_results(mwArray("saved_results.mat"));
			mwArray printed_results(mwArray(""));
			mwArray saved_results(mwArray(""));
			
			// matrix dimensions based on test case; they need to be revised if other case is used
			// for C code we need the total number of elements, while the matrices will be passed to MATLAB as mwArray with rows and columns
			// BUS DATA MATRIX DEFINITION
			// bus matrix dimensions, and total number of elements
			// int nbrows = 9, nbcolumns = 13, nbelem = nbrows * nbcolumns;
			int nbelem = nbrows * nbcolumns;
			vector<double> bus(nbelem);
			mwArray mwBusT(nbcolumns, nbrows, mxDOUBLE_CLASS); // given the way we read the file, we initially get the transpose of the matrix
			mwArray mwBus(nbrows, nbcolumns, mxDOUBLE_CLASS);
      
			// GENERATOR DATA MATRIX DEFINITION
			// generator matrix dimensions, and total number of elements
			// int ngrows = 3, ngcolumns = 21, ngelem = ngrows * ngcolumns;
			int ngelem = ngrows * ngcolumns;
			vector<double> gen(ngelem);
			mwArray mwGenT(ngcolumns, ngrows, mxDOUBLE_CLASS);
			mwArray mwGen(ngrows, ngcolumns, mxDOUBLE_CLASS);
      
			// BRANCH DATA MATRIX DEFINITION
			// branch matrix dimensions, and total number of elements
			// int nbrrows = 9, nbrcolumns = 13, nbrelem = nbrrows * nbrcolumns;
			int nbrelem = nbrrows * nbrcolumns;
			vector<double> branch(nbrelem);
			mwArray mwBranchT(nbrcolumns, nbrrows, mxDOUBLE_CLASS);
			mwArray mwBranch(nbrrows, nbrcolumns, mxDOUBLE_CLASS);
      
			// AREA DATA MATRIX DEFINITION
			// area matrix dimensions, and total number of elements
			// int narows = 1, nacolumns = 2, naelem = narows * nacolumns;
			int naelem = narows * nacolumns;
			vector<double> area(naelem);
			mwArray mwAreaT(nacolumns, narows, mxDOUBLE_CLASS);
			mwArray mwArea(narows, nacolumns, mxDOUBLE_CLASS);
      
			// GENERATOR COST DATA MATRIX DEFINTION
			// generator cost matrix dimensions, and total number of elements
			// int ncrows = 3, nccolumns = 7, ncelem = ncrows * nccolumns;
			int ncelem = ncrows * nccolumns;
			vector<double> costs(ncelem);
			mwArray mwCostsT(nccolumns, ncrows, mxDOUBLE_CLASS);
			mwArray mwCosts(ncrows, nccolumns, mxDOUBLE_CLASS);
      
			// BUS NUMBERS where the distribution networks are going to be connected
			vector<int> bus_num(nHELICSbuses);
      
			// FEEDER NAMES AND BUS NUMBERS FOR HELICS COMMUNICATION - T&D LEVEL
			// the feeder names and the value of the bus where the feeders are connected to, and the corresponding real and imaginary power
			vector<int> feederBus(nHELICSfeeders);
			vector<string> feederName(nHELICSfeeders);
			vector<double> feederValueReal(nHELICSfeeders);
			vector<double> feederValueImag(nHELICSfeeders);
      
			// static active and reactive power at the buses that are connected to substations
			vector<int> fixed_bus(nbrows);
			vector<double> fixed_pd(nbrows);
			vector<double> fixed_qd(nbrows);
			vector<double> full_pd(nbrows);
			vector<double> full_qd(nbrows);
      
			// calculated real and imaginary voltage at the buses that are connected to substations
			vector<double> sendValReal(nHELICSbuses);
			vector<double> sendValIm(nHELICSbuses);
      
			// calculated LMP values at the buses that are connected to substations
			vector<double> realLMP(nHELICSbuses);
			vector<double> imagLMP(nHELICSbuses);
      
			for (int i = 0; i < nHELICSbuses; i++) {
				realLMP[i] = 0;
				imagLMP[i] = 0;
			}
      
			// bus index in the MATPOWER bus matrix corresponding to the buses connected to substations
			vector<int> modified_bus_ind(nHELICSbuses);
			vector<int> mesgc(nHELICSfeeders); // synchronization only happens when at least one value is received
			bool mesg_rcv = false; // if at least one message is passed between simulators, set the message received flag to TRUE
			bool mesg_snt = false; // MATPOWER is now active, it will send a message that major changes happened at transmission level
			bool solved_opf = false; // activates only when OPF is solved to be able to control when price is sent to GLD
			bool topology_changed = false; // activates only if topology changed, like if a generator is turned off form on, or vice-versa, for example.
			// Generator bus matrix consisting of bus numbers corresponding to the generators that could become out-of service,
			// allowing us to set which generators get off-line, in order to simulate a reduction in generation capacity.
			// MATPOWER should reallocate different generation needs coming from the on-line generators to cover for the lost ones, since load stays constant
			// for MATPOWER: value >  0 means generator is in-service
			//                     <= 0 means generator is out-of-service
			// number of rows and columns in the MATPOWER structure, and the total number of buses
			// int noffgrows = 1, noffgcolumns = 1, noffgelem = noffgrows*noffgcolumns;
			vector<int> offline_gen_bus(noffgelem);
			vector<int> offline_gen_ind(noffgelem);
      
			// times recorded for visualization purposes
			int curr_time = 0; // current time in seconds
			int next_OPF_time = 0; // next time we want to call the opf
			int next_Federate_time = 0; // next time returned by HELICS for the simulator to run
			int curr_hours = 0, curr_minutes = 0, curr_seconds = 0; // current time in hours, minutes, seconds
			vector<int> delta_t(nHELICSfeeders);
			vector<int> prev_time(nHELICSfeeders); // for each feeder we save the time between 2 consecutive received messages
			for (int i = 0; i < nHELICSfeeders; i++) {
				delta_t[i] = 0;
				prev_time[i] = 0;
			}

			int profile_idx;

			// ========================================================================================================================
			// Creating the MPC structure that is going to be used as input for OPF function
			double *p_temp, *q_temp;
			int *pq_length, *receive_flag;
			const char *fields[] = { "baseMVA", "bus", "gen", "branch", "areas", "gencost" };
			mwArray mpc(1, 1, 6, fields);

			// Creating the variable that would set the options for the OPF solver
			const char *optFields[] = { "model", "pf", "cpf", "opf", "verbose", "out", "mips", "clp", "cplex", "fmincon", "glpk", "gurobi", "ipopt", "knitro", "minopf", "mosek", "pfipm", "tralm" };
			mwArray mpopt(1, 1, 18, optFields);
			LINFO << "=================================================";
			LINFO << "========= SETTING UP THE OPTIONS !!!!!===========";
			LINFO << "Setting initial options........";
			mpoption(1, mpopt); // initialize powerflow options to DEFAULT structure
			// Set amount of progress info to be printed during MATPOWER execution
			//   0 - print no progress info
			//   1 - print a little progress info
			//   2 - print a lot of progress info
			//   3 - print all progress info
			mpopt.Get("verbose", 1, 1).Set(mwArray(0));
			// Set up controls for pretty-printing of results
			//  -1 - individual flags control what is printed
			//   0 - do not print anything
			//   1 - print everything
			mpopt.Get("out", 1, 1).Get("all", 1, 1).Set(mwArray(0));
			// AC vs. DC modeling for power flow and OPF formulation
			//  'AC' - use AC formulation and corresponding algs/options
			//  'DC' - use DC formulation and corresponding algs/options
			mpopt.Get("model", 1, 1).Set(mwArray("AC")); // This should normally be AC power flow
			// Setting the DC OPF solver to MIPS, MATPOWER Interior Point Solver
			mpopt.Get("opf", 1, 1).Get("dc", 1, 1).Get("solver", 1, 1).Set(mwArray("DEFAULT")); // "MIPS"
			LINFO << " <<<<<< The DC OPF solver is set to " << mpopt.Get("opf", 1, 1).Get("dc", 1, 1).Get("solver", 1, 1) << ". >>>>>>";
			LINFO << "===================================================";

			execution_time(tBefore, cBefore, "Setting the MATPOWER solver options took ");
      
			// ================================ END OF VARIABLE DECLARATION AND INITIALIZATION =============================================
			// =============================================================================================================================
			// get the MATPOWER model data

			read_model_data(file_name, nbrows, nbcolumns, ngrows, ngcolumns, nbrrows, nbrcolumns, narows, nacolumns, ncrows, nccolumns, nHELICSbuses, nHELICSfeeders, noffgelem, &baseMVA, bus, gen, branch, area, costs, bus_num, feederName, feederBus, offline_gen_bus, &amp_fact);

			execution_time(tBefore, cBefore, "Reading the model file data took ");

			mwBusT.SetData(&bus[0], bus.size());
			// Transposing mwBusT to get the correct bus matrix
			// Careful: it is 1-base indexing because we are working with MATLAB type array mwArray
			mwBus = mwArrayTranspose(nbrows, nbcolumns, mwBusT);
			mwArray mwBusDim = mwBus.GetDimensions();

			mwGenT.SetData(&gen[0], gen.size());
			mwGen = mwArrayTranspose(ngrows, ngcolumns, mwGenT);

			mwBranchT.SetData(&branch[0], branch.size());
			mwBranch = mwArrayTranspose(nbrrows, nbrcolumns, mwBranchT);

			if (area.size() != 0) {
				mwAreaT.SetData(&area[0], area.size());
			}
			mwArea = mwArrayTranspose(narows, nacolumns, mwAreaT);

			mwCostsT.SetData(&costs[0], costs.size());
			mwCosts = mwArrayTranspose(ncrows, nccolumns, mwCostsT);

			// Initialize the MPC structure with the data read from the file
			mpc.Get("baseMVA", 1, 1).Set((mwArray)baseMVA);
			mpc.Get("bus", 1, 1).Set(mwBus);
			mpc.Get("gen", 1, 1).Set(mwGen);
			mpc.Get("branch", 1, 1).Set(mwBranch);
			mpc.Get("areas", 1, 1).Set(mwArea);
			mpc.Get("gencost", 1, 1).Set(mwCosts);

			execution_time(tBefore, cBefore, "Creating the MPC structure took ");

			// The index of the bus in the bus matrix could be different from the number of the bus
			// because buses do not have to be numbered consecutively, or be the same as the index
			for (int ind = 0; ind < nbrows; ind++) {
				// ind is an index in MATLAB, that is it should start at 1
				// In mpc.Get("bus", 1, 1).Get(2, ind, 1), the 2 in the second Get represents the number of indeces the array has
				fixed_bus[ind] = (int)mpc.Get("bus", 1, 1).Get(2, ind + 1, 1);
			}

			// The index of the bus in the bus matrix could be different from the number of the bus
			// because buses do not have to be numbered consecutively, or be the same as the index
			for (int ind = 0; ind < nbrows; ind++) {
				// ind is an index in MATLAB, that is it should start at 1
				// In mpc.Get("bus", 1, 1).Get(2, ind, 1), the 2 in the second Get represents the number of indeces the array has
				fixed_pd[ind] = mpc.Get("bus", 1, 1).Get(2, ind + 1, 3);
				fixed_qd[ind] = mpc.Get("bus", 1, 1).Get(2, ind + 1, 4);
				LDEBUG1 << "Initially, the static ACTIVE power at bus " << bus[ind*nbcolumns] << " is " << fixed_pd[ind] << ".";
				LDEBUG1 << "Initially, the static REACTIVE power at bus " << bus[ind*nbcolumns] << " is " << fixed_qd[ind] << ".";
			}

			// Find the index in the MATPOWER generator matrix corresponding to the buses with generators that could be turned off
			// The bus number and the actual index in the MATPOWER matrix may not coincide
			for (int off_ind = 0; off_ind < noffgelem; off_ind++) {
				for (int gen_ind = 1; gen_ind <= ngrows; gen_ind++) { // in MATLAB indexes start from 1
					if ((int)mpc.Get("gen", 1, 1).Get(2, gen_ind, 1) == offline_gen_bus[off_ind]) {
						offline_gen_ind[off_ind] = gen_ind; // index of the bus in the MATPOWER matrix
						LDEBUG1 << "GENERATOR AT BUS " << mpc.Get("gen", 1, 1).Get(2, offline_gen_ind[off_ind], 1) << " MIGHT BECOME OFF-LINE!!!!";
					}
				}
			}

			// For HELICS integration
			// Subscription - the lookup key is given in the json config file as should match the feeder name that is read from the model

			// Let's get a list of the subscriptions we have 
			vector<string> subscription_keys;
	    	for (int i = 0; i < fed->getInputCount(); i++) {
		        subscription_keys.push_back(fed->getTarget(helics::input_id_t(i)));
	    	}
	    	sort(subscription_keys.begin(), subscription_keys.end());

	    	// have a list of ids for the feeder load subscriptions
	    	vector<helics::input_id_t> feederNameId(feederName.size());
	    	vector<string> feederNameTemp(feederName.size());

	    	// and for the transactive as well
	    	vector<string> dispLoadKey(nHELICSbuses);
	    	vector<helics::input_id_t> dispLoadId(nHELICSbuses);
			vector<string> demandCurveKey(nHELICSbuses);
			vector<helics::input_id_t> demandCurveId(nHELICSbuses);
			vector<string> unrespLoadKey(nHELICSbuses);
			vector<helics::input_id_t> unrespLoadId(nHELICSbuses);

			// vectors to hold the values for the transactive
			vector<double> dispLoadValue(nHELICSbuses);
			vector<double> unrespLoadValue(nHELICSbuses);			
			vector< vector<double> > dispLoadDemandCurveCoeff(nHELICSbuses, vector<double>(3));

	    	// loop through subscriptions and seperate them out into different vectors
			for (vector<string>::size_type i = 0; i != subscription_keys.size(); i++) {
				if (subscription_keys[i].find("distLoad") != string::npos) {
					for (vector<string>::size_type j = 0; j != feederName.size(); j++) {
						if (subscription_keys[i].find(feederName[j]) != string::npos) {
							feederNameTemp[j] = subscription_keys[i];
							auto idTemp = fed->getSubscriptionId(subscription_keys[i]);
							fed->setDefaultValue(idTemp, complex<double>(0,0));
							feederNameId[j] = idTemp;
						}
					}
				} else if (subscription_keys[i].find("demandCurve") != string::npos) {
					for (vector<int>::size_type j = 0; j != bus_num.size(); j++) {
						if (subscription_keys[i].find(to_string(bus_num[j])) != string::npos) {
							demandCurveKey[j] = subscription_keys[i];
							auto idTemp = fed->getSubscriptionId(subscription_keys[i]);
							fed->setDefaultValue(idTemp, string("0,0,0"));
							demandCurveId[j] = idTemp;
						}
					}
				} else if (subscription_keys[i].find("maxQ") != string::npos) {
					for (vector<int>::size_type j = 0; j != bus_num.size(); j++) {
						if (subscription_keys[i].find(to_string(bus_num[j])) != string::npos) {
							dispLoadKey[j] = subscription_keys[i];
							auto idTemp = fed->getSubscriptionId(subscription_keys[i]);
							fed->setDefaultValue(idTemp, 0.0);
							dispLoadId[j] = idTemp;
						}
					}
				} else if (subscription_keys[i].find("unRespLoad") != string::npos) {
					for (vector<int>::size_type j = 0; j != bus_num.size(); j++) {
						if (subscription_keys[i].find(to_string(bus_num[j])) != string::npos) {
							unrespLoadKey[j] = subscription_keys[i];
							auto idTemp = fed->getSubscriptionId(subscription_keys[i]);
							fed->setDefaultValue(idTemp, 0.0);
							unrespLoadId[j] = idTemp;
						}
					}
				}
			}

			if (loglevel > logDEBUG) {
				// debug statements to show the subscriptions
				LDEBUG << "Subscriptions:";
				for(auto it = subscription_keys.begin(); it != subscription_keys.end(); ++it) {
					LDEBUG << "    " << *it ;
				}

				LDEBUG << "Feeders from matpower file:";
				for(auto it = feederName.begin(); it != feederName.end(); ++it) {
					LDEBUG << "    " << *it ;
				}

				LDEBUG << "Feeders from config file:";
				for(auto it = feederNameTemp.begin(); it != feederNameTemp.end(); ++it) {
					LDEBUG << "    " << *it ;
				}

				LDEBUG << "Bus numbers from matpower file:";
				for(auto it = bus_num.begin(); it != bus_num.end(); ++it) {
					LDEBUG << "    " << *it ;
				}

				LDEBUG << "Demand curves from config file:";
				for(auto it = demandCurveKey.begin(); it != demandCurveKey.end(); ++it) {
					LDEBUG << "    " << *it ;
				}

				LDEBUG << "Maximum qunatity from config file:";
				for(auto it = dispLoadKey.begin(); it != dispLoadKey.end(); ++it) {
					LDEBUG << "    " << *it ;
				}

				LDEBUG << "Unresponsive load from config file:";
				for(auto it = unrespLoadKey.begin(); it != unrespLoadKey.end(); ++it) {
					LDEBUG << "    " << *it ;
				}
			}
			

			// Let's get a list of the publications we have 
			vector<string> publication_keys;
			publication_keys = vectorizeAndSortQueryResult(fed->query(fed->getName(), "publications"));

			vector<string> pubVoltageKey(nHELICSbuses); // topics under which MATPOWER publishes voltages
			vector<helics::publication_id_t> pubVoltageId(nHELICSbuses); 
			vector<string> pubDispLoadKey(nHELICSbuses); // topics under which MATPOWER publishes the dispatched load after OPF, in MW 
			vector<helics::publication_id_t> pubDispLoadId(nHELICSbuses);
			vector<string> pubPriceKey(nHELICSbuses); // topics under which MATPOWER publishes prices/LMPs
			vector<helics::publication_id_t> pubPriceId(nHELICSbuses);

			// loop through publications and seperate them out into different vectors bid price and quantity
			for (vector<string>::size_type i = 0; i != publication_keys.size(); i++) {
				if (publication_keys [i].find("voltage") != string::npos) {
					for (vector<int>::size_type j = 0; j != bus_num.size(); j++) {
						if (publication_keys[i].find(to_string(bus_num[j])) != string::npos) {
							pubVoltageKey[j] = publication_keys[i];
							auto idTemp = fed->getPublicationId(publication_keys[i]);
							pubVoltageId[j] = idTemp;
						}
					}
				} else if (publication_keys[i].find("dispLoad") != string::npos) {
					for (vector<int>::size_type j = 0; j != bus_num.size(); j++) {
						if (publication_keys[i].find(to_string(bus_num[j])) != string::npos) {
							pubDispLoadKey[j] = publication_keys[i];
							auto idTemp = fed->getPublicationId(publication_keys[i]);
							pubDispLoadId[j] = idTemp;
						}
					}
				} else if (publication_keys[i].find("lmp") != string::npos) {
					for (vector<int>::size_type j = 0; j != bus_num.size(); j++) {
						if (publication_keys[i].find(to_string(bus_num[j])) != string::npos) {
							pubPriceKey[j] = publication_keys[i];
							auto idTemp = fed->getPublicationId(publication_keys[i]);
							pubPriceId[j] = idTemp;
						}
					}
				}
			}

			if (loglevel > logDEBUG) {
				// debug statements to show the publications
				LDEBUG << "Publications:";
				for(auto it = publication_keys.begin(); it != publication_keys.end(); ++it) {
					LDEBUG << "    " << *it ;
				}

				LDEBUG << "voltage:";
				for(auto it = pubVoltageKey.begin(); it != pubVoltageKey.end(); ++it) {
					LDEBUG << "    " << *it ;
				}

				LDEBUG << "dispatchable load:";
				for(auto it = pubDispLoadKey.begin(); it != pubDispLoadKey.end(); ++it) {
					LDEBUG << "    " << *it ;
				}

				LDEBUG << "LMP:";
				for(auto it = pubPriceKey.begin(); it != pubPriceKey.end(); ++it) {
					LDEBUG << "    " << *it ;
				}
			}

			// some unit strings that might not be needed anymore
			string voltUnit = "V"; // unit for the published voltage
			string priceUnit = "$/MWh"; // unit for the published price/LMP (the CCSI needs price in $/MWH)			

			execution_time(tBefore, cBefore, "Setting the published topics took ");

			// ==========================================================================================================
			// Uncomment the line below when running with HELICS
			// we are done with the setup, start the initialization
		    LINFO << "federate entering init mode";
		    fed->enterInitializingMode ();

		    // now enter execution state
		    fed->enterExecutingMode ();
		    LINFO << "federate entering exec mode";

			execution_time(tBefore, cBefore, "Initializing HELICS took ");

			// ==========================================================================================================

			// After HELICS is initialized we can adjust the start time to be one timestep earlier than when the OPF results
			// are needed in other applications. This time is dictated by the zpl file.
			next_Federate_time = marketTime - wholesaleTimeShift;
			next_OPF_time = next_Federate_time;
			do {
				// Start every time assuming no message is received or sent
				mesg_rcv = false;
				mesg_snt = false;
				solved_opf = false;
				topology_changed = false;
        
				// ==========================================================================================================
				// =============== CURRENT SIMULATION TIME ==================================================================
				// curr_time = next_Federate_time;
				curr_hours = curr_time / 3600;
				curr_minutes = (curr_time - 3600 * curr_hours) / 60;
				curr_seconds = curr_time - 3600 * curr_hours - 60 * curr_minutes;
				// ==========================================================================================================

				profile_idx = 12 * (curr_hours % 24) + curr_minutes / 5;

				// Setting the load at the load buses based on a one-day long profile. WARNING: if the model is changed these need to be readjusted
				for (int ind = 0; ind < nbrows; ind++) {
					// get the fixed_pd and fixed_qd from the load profiles
					fixed_pd[ind] = real_power_demand[ind][profile_idx];
					fixed_qd[ind] = reactive_power_demand[ind][profile_idx];
					LDEBUG1 << "fixed active -->> " << fixed_pd[ind] << "(" << mpc.Get("bus", 1, 1).Get(2, ind + 1, 3) << ") at bus " << bus[ind*nbcolumns] << " (" << mpc.Get("bus", 1, 1).Get(2, ind + 1, 1) << ")";
					LDEBUG1 << "fixed reactive -->> " << fixed_qd[ind] << "(" << mpc.Get("bus", 1, 1).Get(2, ind + 1, 4) << ") at bus " << bus[ind*nbcolumns] << " (" << mpc.Get("bus", 1, 1).Get(2, ind + 1, 1) << ")";        
				}
				execution_time(tBefore, cBefore, "Calculating current loads according to their profile values took ");

#pragma omp parallel for num_threads(NUM_THREADS)
				for (int feederInd = 0; feederInd < nHELICSfeeders; feederInd++) {
					getpower(fed, feederNameId[feederInd], &mesgc[feederInd], &feederValueReal[feederInd], &feederValueImag[feederInd]);					
				}

				execution_time(tBefore, cBefore, "Getting power from all GLDs took ");

				for (int feederInd = 0; feederInd < nHELICSfeeders; feederInd++) {
					mesg_rcv = mesg_rcv || (bool)mesgc[feederInd];
					if (mesgc[feederInd] == 1) { // if one substation publishes a change in load, then update the value in the BUS matrix for the transmission network power flow solver
						delta_t[feederInd] = curr_time - prev_time[feederInd]; // number of seconds between 2 consecutive received messages
						// It is assumed that the load at the bus consists of the non-controllable load from the predefined profiles plus a controllable load coming from distribution (GridLAB-D)
						// To simulate the idea of having a more substantial change in load at the substantion level, consider we have amp_fact similar models at on node
						// That is why I multiply by amp_fact below.
					} // end IF(mesgc)
				}

				execution_time(tBefore, cBefore, "Update if message is received took ");

				// setting the starting point for the full load vectors
				full_pd = fixed_pd;
				full_qd = fixed_qd;

				for (int feederInd = 0; feederInd < nHELICSfeeders; feederInd++) {
					// now we add the GLD load to the fixed vectors
					for (int ind = 0; ind < nbrows; ind++) {
						if (fixed_bus[ind] == feederBus[feederInd]) {
							full_pd[ind] += amp_fact * feederValueReal[feederInd];
							full_qd[ind] += amp_fact * feederValueImag[feederInd];
							break;
						}
					}

				} // end FOR(sub_ind)

				execution_time(tBefore, cBefore, "Updating fixed profiles took ");

				// Setting the load at the load buses based on a one-day long profile. WARNING: if the model is changed these need to be readjusted
				for (int ind = 0; ind < nbrows; ind++) {
					mpc.Get("bus", 1, 1).Get(2, ind + 1, 3).Set((mwArray)full_pd[ind]);
					mpc.Get("bus", 1, 1).Get(2, ind + 1, 4).Set((mwArray)full_qd[ind]);
				}
				execution_time(tBefore, cBefore, "Setting current loads according to their profile values took ");

				if (mesg_rcv) { // If at least one distribution network publishes
					// ==========================================================================================================
					// Uncomment after testing the load profile loading correctly
					// cout << "\033[2J\033[1;1H"; // Just a trick to clear the screen before printing the new results at the terminal
					LINFO << "================ It has been " << curr_hours << " hours, " << curr_minutes << " minutes, and " << curr_seconds << " seconds. =================";
					LINFO << "====== New published values from the distribution networks exist. ================";

					for (int feederInd = 0; feederInd < nHELICSfeeders; feederInd++) {
						if (mesgc[feederInd] == 1) {
							LDEBUG1 << "====== New ACTIVE power from GRIDLab-D AT " << feederName[feederInd] << " at bus " << feederBus[feederInd] << " is " << feederValueReal[feederInd] << " MW ======";
							LDEBUG1 << "====== New REACTIVE power from GRIDLab-D AT " << feederName[feederInd] << " at bus " << feederBus[feederInd] << " is " << feederValueImag[feederInd] << " Mvar ======";
							LDEBUG1 << "I've got the NEW POWER after " << delta_t[feederInd] << " seconds.";
							prev_time[feederInd] = curr_time;
						}
						else {
							// Uncomment after testing the load profile loading correctly
							LDEBUG1 << "===== NO LOAD CHANGE AT " << feederName[feederInd] << " AT BUS " << feederBus[feederInd] << " =====================";
						} // end IF(mesgc)
					} // end FOR(sub_ind)
					if (loglevel >= logDEBUG) { // this is an expensive loop so we first check the log level
						for (int bus_ind = 0; bus_ind < nHELICSbuses; bus_ind++) { // only for printing/debugging purposes
							for (int ind = 1; ind <= nbrows; ind++) {
								if ((int)mpc.Get("bus", 1, 1).Get(2, ind, 1) == bus_num[bus_ind]) {
									LDEBUG1 << "Total ACTIVE power required at bus: " << bus_num[bus_ind] << " is " << mpc.Get("bus", 1, 1).Get(2, ind, 3) << " MW.";
									LDEBUG1 << "Total REACTIVE power required at bus: " << bus_num[bus_ind] << " is " << mpc.Get("bus", 1, 1).Get(2, ind, 4) << " MVAR.";
									break;
								}
							}
						} // end FOR(bus_ind)
					}
				} // end IF(mesg_rcv)
				execution_time(tBefore, cBefore, "Printing debug messages took ");

				// setting renewable generation profile
				for (int ind = 0; ind < ngrows; ind++) {
					if (renewable_generation[ind][profile_idx] > 0) {
						//mpc.Get("gen", 1, 1).Get(2, ind+1, 2).Set((mwArray) renewable_generation[ind][profile_idx]);
						mpc.Get("gen", 1, 1).Get(2, ind + 1, 9).Set((mwArray) renewable_generation[ind][profile_idx]);
						mpc.Get("gen", 1, 1).Get(2, ind + 1, 10).Set((mwArray) 0);
						LDEBUG1 << "fixed renewable generation -->> " << renewable_generation[ind][profile_idx];
					}
				}
				execution_time(tBefore, cBefore, "Setting renewable generation according to their profile values took ");

				// Setting up the status of the generators, based on the current time
				// Turning some generators out-of-service between certain time preiods in the simulation 
				// every day between 6 and 7 or 18 and 19 !!! WARNING !!! These hours are hard coded assuming we run more than 24 hours
				if ((curr_hours % 24 >= 6 && curr_hours % 24 < 7) || (curr_hours % 24 >= 18 && curr_hours % 24 < 19)) {
					for (int off_ind = 0; off_ind < noffgelem; off_ind++) {
						if ((double)mpc.Get("gen", 1, 1).Get(2, offline_gen_ind[off_ind], 8) == 1) { // if generator is ON
							mpc.Get("gen", 1, 1).Get(2, offline_gen_ind[off_ind], 8).Set((mwArray)0); // turn generator OFF, and set flag that topology has changed
							topology_changed = topology_changed || true; // signal that at least one generator changed its state
							//mesg_snt = mesg_snt || true; // signal that at least one generator changed its state
							// Uncomment after testing the load profile loading correctly
							LDEBUG1 << "============ Generator at bus " << mpc.Get("gen", 1, 1).Get(2, offline_gen_ind[off_ind], 1);
							LDEBUG1 << " is put OUT-OF-SERVICE. ==================";
						}
					}

					execution_time(tBefore, cBefore, "Checking if generators are to be turned OFF took ");
				}
				else {
					for (int off_ind = 0; off_ind < noffgelem; off_ind++) {
						if ((double)mpc.Get("gen", 1, 1).Get(2, offline_gen_ind[off_ind], 8) == 0) { // if generator is OFF
							mpc.Get("gen", 1, 1).Get(2, offline_gen_ind[off_ind], 8).Set((mwArray)1); // turn generator ON, and set flag that topology changed
							topology_changed = topology_changed || true;// signal that at least one generator changed its state
							//mesg_snt = mesg_snt || true; // signal that at least one generator changed its state
							// Uncomment after testing the load profile loading correctly
							LDEBUG1 << "============ Generator at bus " << mpc.Get("gen", 1, 1).Get(2, offline_gen_ind[off_ind], 1);
							LDEBUG1 << " is brought back IN-SERVICE. ==================";
						}
					}

					execution_time(tBefore, cBefore, "Checking if generators are to be turned OFF took ");
				}

				// JH: adding to capture the total load on the system. This is needed by the govenor
				if (prevTotalLoad == -1) {
					mwdeltaLoad = 0.0;
				} else {
					totalLoad = 0.0;
					for (int ind = 0; ind < nbrows; ind++) {
						totalLoad += (double)mpc.Get("bus", 1, 1).Get(2, ind + 1, 3);
					}
					// calculate the delta power for the govenor
					mwdeltaLoad = totalLoad - prevTotalLoad;
				}
			
				// Running the actual transmission simulator, by solving the power flow, or the optimal power flow
				if (curr_time == next_OPF_time || topology_changed){
					// ========================================================
					// Laurentiu Dan Marinovici - 2018/05/03
					// Adding the part that allows running 2 scenarios:
					//   - one purely simple T&D case
					//   - one that involves TE algorithm
					// ========================================================
					if (withTE) {
						// Transactive Energy scenario
						// ========================================================
						// Laurentiu Dan Marinovici - 2017/06/26
						// Adding the dispatchable load and bidding curve
						// ========================================================
						LINFO << "================= Trying to get the DISPATCHABLE LOAD PART, at current time. ================== " << curr_time;
						for (int bus_ind = 0; bus_ind < nHELICSbuses; bus_ind++) {
							for (int genRowInd = 1; genRowInd <= ngrows; genRowInd++) {
								// A distribution/load bus could be part of the generation matrix as negative generation
								// if it supplies controllable loads; however, there are times when no available controllable loads exist;
								// that is when those dispatchable load buses are set as disabled in the generation matrix, and do not participate in OPF.
								// Also, if it turns out that one of the generator buses also has load on it, and that load is dispatchable, the bus will
								// show up in the generator matrix twice, and hence a test to see if it is a normal or negative generation bus should be performed (see last
								// 2 tests in the following IF statement)              
								if ((int)mpc.Get("gen", 1, 1).Get(2, genRowInd, 1) == bus_num[bus_ind] && (double)mpc.Get("gen", 1, 1).Get(2, genRowInd, 9) <= 0 && (double)mpc.Get("gen", 1, 1).Get(2, genRowInd, 10) <= 0) {
									getUnrespLoad(fed, unrespLoadId[bus_ind], &unrespLoadValue[bus_ind]);
									for (int busRowInd = 0; busRowInd < nbrows; busRowInd++) {
										if ((int)mpc.Get("bus", 1, 1).Get(2, busRowInd + 1, 1) == bus_num[bus_ind]) {
											// JH
											//mpc.Get("bus", 1, 1).Get(2, busRowInd, 3).Set((mwArray) ((double) mpc.Get("bus", 1, 1).Get(2, busRowInd, 3) + unrespLoadValue[bus_ind]));
											mpc.Get("bus", 1, 1).Get(2, busRowInd + 1, 3).Set((mwArray)(fixed_pd[busRowInd] + unrespLoadValue[bus_ind]));
											LDEBUG1 << " =============== bus_num = " << bus_num[bus_ind] << ", unresp load = " << unrespLoadValue[bus_ind] << " ===========================";
											break;
										}
									}
									getDispLoad(fed, dispLoadId[bus_ind], &dispLoadValue[bus_ind]);
									if (dispLoadValue[bus_ind] == 0) { // that is, there are no available controllable loads
										mpc.Get("gen", 1, 1).Get(2, genRowInd, 8).Set(mwArray(0));
										LINFO << "** No available controllable loads at bus " << bus_num[bus_ind];
										LINFO << "** so I am turning off the negative generation corresponding to this bus.";
									}
									else {
										mpc.Get("gen", 1, 1).Get(2, genRowInd, 8).Set(mwArray(1));
										mpc.Get("gen", 1, 1).Get(2, genRowInd, 10).Set(mwArray(-dispLoadValue[bus_ind]));
										getDLDemandCurve(fed, demandCurveId[bus_ind], &dispLoadDemandCurveCoeff[bus_ind][0], &dispLoadDemandCurveCoeff[bus_ind][1], &dispLoadDemandCurveCoeff[bus_ind][2]);
										mpc.Get("gencost", 1, 1).Get(2, genRowInd, 4).Set(mwArray(3));
										mpc.Get("gencost", 1, 1).Get(2, genRowInd, 5).Set((mwArray)(-dispLoadDemandCurveCoeff[bus_ind][0]));
										mpc.Get("gencost", 1, 1).Get(2, genRowInd, 6).Set((mwArray)(dispLoadDemandCurveCoeff[bus_ind][1]));
										mpc.Get("gencost", 1, 1).Get(2, genRowInd, 7).Set((mwArray)(-dispLoadDemandCurveCoeff[bus_ind][2]));
									}
								}
							}
						}

						execution_time(tBefore, cBefore, "Setting the dispatchable loads (if any) took ");

						// Call OPF with nargout = 0 (first argument), and all results are going to be printed at the console
						// Call OPF with nargout = 7, and get all the output parameters up to et
						// Call OPF with nargout = 11, and get a freaking ERROR.... AVOID IT!
						// cout << "================= Solving the OPTIMAL POWER FLOW. ==================" << endl;

						LDEBUG2 << "== New generator matrix before DC OPF ==";
						LDEBUG2 << mpc.Get("gen", 1, 1);
						LDEBUG2 << "== New bus matrix before DC OPF ==";
						LDEBUG2 << mpc.Get("bus", 1, 1);
						LDEBUG2 << "== New gencost matrix before DC OPF ==";
						LDEBUG2 << mpc.Get("gencost", 1, 1);
						// mpopt.Get("model", 1, 1).Set(mwArray("DC"));
						runopf(8, mwMVAbase, mwBusOut, mwGenOut, mwGenCost, mwBranchOut, f, success, et, mpc, mpopt, printed_results, saved_results);

						if ((int) success == 0) {
							LWARNING << "Failed to solve the AC OPF @ market cycle. (at time " << curr_time << ")";
						}

						execution_time(tBefore, cBefore, "Running OPF took ");

						// ============ DISPATCHABLE LOAD (NEGATIVE GENERATOR) METRICS ======================
						for (int genInd = 1; genInd <= ngrows; genInd++) { // indexing in a MATLAB matrix structure
							if ((double)mwGenOut.Get(2, genInd, 9) <= 0 && (double)mwGenOut.Get(2, genInd, 10) <= 0) { // only for dispatchable loads (negative generators)
								mpDispLoadValues.clearBusValues();
								mpDispLoadValues.setGenIndex((int)genInd);
								mpDispLoadValues.setBusID((int)mwGenOut.Get(2, genInd, 1));
								mpDispLoadValues.setBusPG((double)mwGenOut.Get(2, genInd, 2) * (-1));
								mpDispLoadValues.setBusQG((double)mwGenOut.Get(2, genInd, 3) * (-1));
								mpDispLoadValues.setBusStatus((double)mwGenOut.Get(2, genInd, 8));
								for (int busInd = 1; busInd <= nbrows; busInd++) {
									if ((int)mwGenOut.Get(2, genInd, 1) == (int)mwBusOut.Get(2, busInd, 1)) {
										mpDispLoadValues.setBusLAMP((double)mwBusOut.Get(2, busInd, 14));
										mpDispLoadValues.setBusLAMQ((double)mwBusOut.Get(2, busInd, 15));
										break;
									}
								}
								mpDispLoadMetrics.setBusValues(mpDispLoadValues);
								// Now that the OPF done we will also need to turn of the dispatchable load
								mpc.Get("gen", 1, 1).Get(2, genInd, 8).Set(mwArray(0));
							}
						}

						// loop to puclish dispatchable loads
						for (int bus_ind = 0; bus_ind < nHELICSbuses; bus_ind++) {
							for (int genInd = 1; genInd <= ngrows; genInd++) { // indexing in a MATLAB matrix structure
								if ((double)mwGenOut.Get(2, genInd, 9) <= 0 && (double)mwGenOut.Get(2, genInd, 10) <= 0) { // only for dispatchable loads (negative generators)
									if ((int) (int)mwGenOut.Get(2, genInd, 1) == bus_num[bus_ind]) {
										double tempDL = (double) mwGenOut.Get(2, genInd, 2) * (-1.);
										fed->publish<double>(pubDispLoadId[bus_ind], tempDL);
										LDEBUG << "publishing dispatchable load at bus " << bus_num[bus_ind] << " on key " << pubDispLoadKey[bus_ind] << " with value " << tempDL;
									}
								}
							}
						}

						execution_time(tBefore, cBefore, "Creating dispatchable load metrics took ");

						mpDispLoadMetrics.setCurrentTimeBusValues(curr_time);
						// Bring system in the new state by replacing the bus, generator, branch and generator cost matrices with the calculated ones
						mpc.Get("gen", 1, 1).Set(mwGenOut);
						mpc.Get("bus", 1, 1).Set(mwBusOut);
						mpc.Get("branch", 1, 1).Set(mwBranchOut);
						mpc.Get("gencost", 1, 1).Set(mwGenCost);
						LDEBUG2 << "== New generator matrix after DC OPF ==";
						LDEBUG2 << mpc.Get("gen", 1, 1);
						LDEBUG2 << "== New bus matrix after DC OPF ==";
						LDEBUG2 << mpc.Get("bus", 1, 1);
						LDEBUG2 << "== New gencost matrix after DC OPF ==";
						LDEBUG2 << mpc.Get("gencost", 1, 1);

						double tempDispLoad = 0.0;
						for (int genInd = 1; genInd <= ngrows; genInd++) { // indexing in a MATLAB matrix structure
							if ((double)mwGenOut.Get(2, genInd, 9) <= 0 && (double)mwGenOut.Get(2, genInd, 10) <= 0) { // only for dispatchable loads (negative generators)
								tempDispLoad += (double)mwGenOut.Get(2, genInd, 2) * (-1);
							}
						}

						// JH: adding to capture the total load on the system. This is needed by the govenor
						double tempTotalLoad = 0.0;
						for (int ind = 0; ind < nbrows; ind++) {
							tempTotalLoad += (double)mpc.Get("bus", 1, 1).Get(2, ind + 1, 3);
						}

						LDEBUG << "========================== Market check ========================";
						LDEBUG << " previous total load -> " << prevTotalLoad / 1000. << "GW \tOPF total load -> " << tempTotalLoad / 1000 << "GW \tDISP total load -> " << tempDispLoad / 1000 << "GW";
						for (int ind = 0; ind < nbrows; ind++) {
							LDEBUG1 << "Bus: " << mpc.Get("bus", 1, 1).Get(2, ind + 1, 1) << "\t\tprofile -> " << fixed_pd[ind] << "\t\topf -> " << mpc.Get("bus", 1, 1).Get(2, ind + 1, 3) << "\t\tDist -> " << full_pd[ind];

						}
						LDEBUG << "================================================================";


						// Setting the load at the load buses based on a one-day long profile and current load from distribution side
						for (int ind = 0; ind < nbrows; ind++) {
							mpc.Get("bus", 1, 1).Get(2, ind + 1, 3).Set((mwArray)full_pd[ind]);
						}

						// This code will run a PF after the OPF, but since se are doing an AC OPF this should not be needed. Leaving in just to be safe
						/*
						execution_time(tBefore, cBefore, "Turning off dispatchable loads to run PF after OPF took ");

						LDEBUG1 << "== New generator matrix before AC PF @ market cycle ==";
						LDEBUG1 << mpc.Get("gen", 1, 1);
						LDEBUG1 << "== New bus matrix before AC PF @ market cycle ==";
						LDEBUG1 << mpc.Get("bus", 1, 1);
						LDEBUG1 << "== New gencost matrix before AC PF @ market cycle ==";
						LDEBUG1 << mpc.Get("gencost", 1, 1);
						// mpopt.Get("model", 1, 1).Set(mwArray("AC")); // This should normally be AC power flow

						// JH: at the moment we will not consider the case if the OPF was significantly off (no govenor here)
						runpf(6, mwMVAbase, mwBusOut, mwGenOut, mwBranchOut, success, et, mpc, mpopt, printed_results, saved_results);

						if ((int) success == 0) {
							LWARNING << "Failed to solve the AC PF @ market cycle. (at time " << curr_time << ")";
						}

						// Bring system in the new state by replacing the bus, generator, and branch matrices with the calculated ones
						mpc.Get("gen", 1, 1).Set(mwGenOut);
						mpc.Get("bus", 1, 1).Set(mwBusOut);
						mpc.Get("branch", 1, 1).Set(mwBranchOut);
						LDEBUG1 << "== New generator matrix after AC PF @ market cycle ==";
						LDEBUG1 << mpc.Get("gen", 1, 1);
						LDEBUG1 << "== New bus matrix after AC PF @ market cycle ==";
						LDEBUG1 << mpc.Get("bus", 1, 1);
						LDEBUG1 << "== New gencost matrix after AC PF @ market cycle ==";
						LDEBUG1 << mpc.Get("gencost", 1, 1);

						execution_time(tBefore, cBefore, "Running PF after OPF (TE scenario) took ");
						*/
					}
					else {
						// pure T&D case
						// cout << "================= Solving the OPTIMAL POWER FLOW. ==================" << endl;
						LDEBUG2 << "== New generator matrix before T&D OPF ==";
						LDEBUG2 << mpc.Get("gen", 1, 1);
						LDEBUG2 << "== New bus matrix before T&D OPF ==";
						LDEBUG2 << mpc.Get("bus", 1, 1);
						LDEBUG2 << "== New gencost matrix before T&D OPF ==";
						LDEBUG2 << mpc.Get("gencost", 1, 1);
						// mpopt.Get("model", 1, 1).Set(mwArray("DC"));
						runopf(8, mwMVAbase, mwBusOut, mwGenOut, mwGenCost, mwBranchOut, f, success, et, mpc, mpopt, printed_results, saved_results);

						if ((int)success == 0) {
							LWARNING << "Failed to solve the T&D AC OPF. (at time " << curr_time << ")";
						}

						execution_time(tBefore, cBefore, "Running T&D OPF took ");

						// Bring system in the new state by replacing the bus, generator, branch and generator cost matrices with the calculated ones
						mpc.Get("gen", 1, 1).Set(mwGenOut);
						mpc.Get("bus", 1, 1).Set(mwBusOut);
						mpc.Get("branch", 1, 1).Set(mwBranchOut);
						mpc.Get("gencost", 1, 1).Set(mwGenCost);
						LDEBUG2 << "== New generator matrix after T&D OPF ==";
						LDEBUG2 << mpc.Get("gen", 1, 1);
						LDEBUG2 << "== New bus matrix after T&D OPF ==";
						LDEBUG2 << mpc.Get("bus", 1, 1);
						LDEBUG2 << "== New gencost matrix after T&D OPF ==";
						LDEBUG2 << mpc.Get("gencost", 1, 1);
                       
						// With the new generation dispatch, run an AC PF to recalculate the bus voltages.
						// mpopt.Get("model", 1, 1).Set(mwArray("AC")); // This should normally be AC power flow

						// JH: at the moment we will not consider the case if the OPF was significantly off (no govenor here)
						runpf(6, mwMVAbase, mwBusOut, mwGenOut, mwBranchOut, success, et, mpc, mpopt, printed_results, saved_results);

						if ((int)success == 0) {
							LWARNING << "Failed to solve the T&D AC PF. (at time " << curr_time << ")";
						}
              
						// Bring system in the new state by replacing the bus, generator, and branch matrices with the calculated ones
						mpc.Get("gen", 1, 1).Set(mwGenOut);
						mpc.Get("bus", 1, 1).Set(mwBusOut);
						mpc.Get("branch", 1, 1).Set(mwBranchOut);

						LDEBUG2 << "== New generator matrix after T&D AC PF ==";
						LDEBUG2 << mpc.Get("gen", 1, 1);
						LDEBUG2 << "== New bus matrix after T&D AC PF  ==";
						LDEBUG2 << mpc.Get("bus", 1, 1);

						execution_time(tBefore, cBefore, "Running PF after OPF (T&D scenario) took ");

					}
					solved_opf = true;
					mesg_snt = mesg_snt || true;
					next_OPF_time = min(curr_time + marketTime, simStopTime);
				}            
				else {
					// cout << "================= Solving the POWER FLOW. ==================" << endl;
					// Active dispatchable loads/negative generations are turned off, even though they should all
					// have been turned off before solving the AC PF at the market cycle; bust just making sure, I think.
					LDEBUG2 << "== New generator matrix before AC PF ==";
					LDEBUG2 << mpc.Get("gen", 1, 1);
					LDEBUG2 << "== New bus matrix before AC PF ==";
					LDEBUG2 << mpc.Get("bus", 1, 1);
					LDEBUG2 << "== New gencost matrix before AC PF ==";
					LDEBUG2 << mpc.Get("gencost", 1, 1);

					for (int busInd = 0; busInd < nHELICSbuses; busInd++) {
						for (int genRowInd = 1; genRowInd <= ngrows; genRowInd++) {
							if ((int)mpc.Get("gen", 1, 1).Get(2, genRowInd, 1) == bus_num[busInd] && (int)mpc.Get("gen", 1, 1).Get(2, genRowInd, 8) == 1) {
								mpc.Get("gen", 1, 1).Get(2, genRowInd, 8).Set(mwArray(0));
							}
						}
					}
					// mpopt.Get("model", 1, 1).Set(mwArray("AC")); // This should normally be AC power flow

					// log the delta power used for the govenor
					LINFO << "== Power imbalance before running governor -> " << mwdeltaLoad << " (at time " << curr_time << " ==";

					// JH: adding new PF function that includes gonevor control
					//runpf(6, mwMVAbase, mwBusOut, mwGenOut, mwBranchOut, success, et, mpc, mpopt, printed_results, saved_results);
					runpf_gov(6, mwMVAbase, mwBusOut, mwGenOut, mwBranchOut, success, et, mpc, mwdeltaLoad, mpopt, printed_results, saved_results);
				
					if ((int) success == 0) {
						LWARNING << "Failed to solve AC PF, so reverting the outputs back. (at time " << curr_time << ")";
						mwBusOut = mpc.Get("bus", 1, 1);
						mwGenOut = mpc.Get("gen", 1, 1);
						mwBranchOut = mpc.Get("branch", 1, 1);
					}
					else {
						// Bring system in the new state by replacing the bus, generator, and branch matrices with the calculated ones
						mpc.Get("gen", 1, 1).Set(mwGenOut);
						mpc.Get("bus", 1, 1).Set(mwBusOut);
						mpc.Get("branch", 1, 1).Set(mwBranchOut);
					}


					LDEBUG2 << "== New generator matrix after AC PF ==";
					LDEBUG2 << mpc.Get("gen", 1, 1);
					LDEBUG2 << "== New bus matrix after AC PF ==";
					LDEBUG2 << mpc.Get("bus", 1, 1);

					execution_time(tBefore, cBefore, "Running regular PF took ");
				}

				if (mesg_rcv || mesg_snt) {
					if (mesg_snt) { // only cleaning the screen when MATPOWER initiates the message transfer; otherwise is cleaned when message is received
						// Uncomment after testing the load profile loading correctly
						// cout << "\033[2J\033[1;1H"; // Just a trick to clear the screen before pritning the new results at the terminal
						if (solved_opf && !topology_changed) {
							LINFO << "================ It has been " << curr_hours << " hours, " << curr_minutes << " minutes, and " << curr_seconds << " seconds. =================" ;
							LINFO << "== MATPOWER publishing voltage values after dispatching new generation profile. ==" ;
						}
						else {
							LINFO << "================ It has been " << curr_hours << " hours, " << curr_minutes << " minutes, and " << curr_seconds << " seconds. =================" ;
							LINFO << "== MATPOWER publishing voltage new values due to topology change. ================" ;
						}
					}
					for (int bus_ind = 0; bus_ind < nHELICSbuses; bus_ind++) {
						for (int ind = 1; ind <= nbrows; ind ++) { // need to find the corresponding bus row in the BUS matrix
							if ((int) mwBusOut.Get(2, ind, 1) == bus_num[bus_ind]) {
								sendValReal[bus_ind] =  (double) mwBusOut.Get(2, ind, 8)*cos((double) mwBusOut.Get(2, ind, 9) * PI / 180)*(double) mwBusOut.Get(2, ind, 10)*1000; // real voltage at the bus based on the magnitude (column 8 of the output bus matrix) and angle in degrees (column 9 of the output bus matrix), from pu to kV to V
								sendValIm[bus_ind] = (double) mwBusOut.Get(2, ind, 8)*sin((double) mwBusOut.Get(2, ind, 9) * PI / 180)*(double) mwBusOut.Get(2, ind, 10)*1000; // imaginary voltage at the bus based on the magnitude (column 8 of the output bus matrix) and angle in degrees (column 9 of the output bus matrix), from pu to kV to V                
								if (withTE && solved_opf) {
									realLMP[bus_ind] = (double) mwBusOut.Get(2, ind, 14); // local marginal price based on the Lagrange multiplier on real power mismatch (column 14 of the output bus matrix). price is in $/MWh
									imagLMP[bus_ind] = (double) mwBusOut.Get(2, ind, 15); // local marginal price based on the Lagrange multiplier on reactive power mismatch (column 14 of the output bus matrix
									// =========================================================================================================================
									// Price will be sent only when an OPF has been solved
									fed->publish<double>(pubPriceId[bus_ind], realLMP[bus_ind]);
									LDEBUG << "====== MARKET CYCLE FINISHED WITH PUBLISHED LMP " << realLMP[bus_ind] << " $/MWh, FOR " << " at bus " << bus_num[bus_ind];
								}
								break;
							}
						}
						complex<double> complexVoltage = {sendValReal[bus_ind], sendValIm[bus_ind]};
						fed->publish<complex<double>>(pubVoltageId[bus_ind], complexVoltage);
						LDEBUG << "====== PUBLISHING NEW VOLTAGE " << complexVoltage << " " << voltUnit << " at bus " << bus_num[bus_ind];
					}

					execution_time(tBefore, cBefore, "Calculating and publishing voltages and/or prices took ");
				}

				// ================== LOAD/DISTRIBUTION BUS VALUES METRICS =======================================
				for (int busInd = 1; busInd <= nbrows; busInd++) { // need to find the corresponding bus row in the BUS matrix
					if ((int)mwBusOut.Get(2, busInd, 2) != 2) { // collecting the metrics for all load buses, that is all PQ buses in bus matrix
						mpLoadBusValues.clearBusValues();
						mpLoadBusValues.setBusID((int)mwBusOut.Get(2, busInd, 1));
						if (curr_time < marketTime - wholesaleTimeShift) {
							mpLoadBusValues.setBusLAMP((double)0);
							mpLoadBusValues.setBusLAMQ((double)0);
						}
						else {
							mpLoadBusValues.setBusLAMP((double)mwBusOut.Get(2, busInd, 14));
							mpLoadBusValues.setBusLAMQ((double)mwBusOut.Get(2, busInd, 15));
						}
						mpLoadBusValues.setBusPD((double)mwBusOut.Get(2, busInd, 3));
						mpLoadBusValues.setBusQD((double)mwBusOut.Get(2, busInd, 4));
						mpLoadBusValues.setBusVA((double)mwBusOut.Get(2, busInd, 9));
						mpLoadBusValues.setBusVM((double)mwBusOut.Get(2, busInd, 8));
						mpLoadBusValues.setBusVMAX((double)mwBusOut.Get(2, busInd, 12));
						mpLoadBusValues.setBusVMIN((double)mwBusOut.Get(2, busInd, 13));
						mpLoadMetrics.setBusValues(mpLoadBusValues);
					}
				}

				execution_time(tBefore, cBefore, "Load metrics setup took ");

				// ============ GENERATOR METRICS ======================
				for (int genInd = 1; genInd <= ngrows; genInd++) { // indexing in a MATLAB matrix structure
					if ((double)mwGenOut.Get(2, genInd, 9) > 0 && (double)mwGenOut.Get(2, genInd, 10) >= 0) { // only for generator, and not dispatchable loads (negative generators)
						mpGeneratorBusValues.clearBusValues();
						mpGeneratorBusValues.setGenIndex((int)genInd);
						mpGeneratorBusValues.setBusID((int)mwGenOut.Get(2, genInd, 1));
						mpGeneratorBusValues.setBusPG((double)mwGenOut.Get(2, genInd, 2));
						mpGeneratorBusValues.setBusQG((double)mwGenOut.Get(2, genInd, 3));
						mpGeneratorBusValues.setBusStatus((double)mwGenOut.Get(2, genInd, 8));
						if (curr_time < marketTime - wholesaleTimeShift) {
							// removing this reduntant search
							mpGeneratorBusValues.setBusLAMP((double)0);
							mpGeneratorBusValues.setBusLAMQ((double)0);
							/*
							for (int busInd = 1; busInd <= nbrows; busInd++) {
								if ((int) mwGenOut.Get(2, genInd, 1) == (int) mwBusOut.Get(2, busInd, 1)) {
									mpGeneratorBusValues.setBusLAMP((double) 0);
									mpGeneratorBusValues.setBusLAMQ((double) 0);
								}
							} */
						}
						else {
							for (int busInd = 1; busInd <= nbrows; busInd++) {
								if ((int)mwGenOut.Get(2, genInd, 1) == (int)mwBusOut.Get(2, busInd, 1)) {
									mpGeneratorBusValues.setBusLAMP((double)mwBusOut.Get(2, busInd, 14));
									mpGeneratorBusValues.setBusLAMQ((double)mwBusOut.Get(2, busInd, 15));
									break;
								}
							}
						}
						mpGeneratorMetrics.setBusValues(mpGeneratorBusValues);
					}
				}
				execution_time(tBefore, cBefore, "Generator metrics setup took ");

				// JH: adding to capture the total load on the system. This is needed by the govenor
				prevTotalLoad = 0.0;
				for (int ind = 0; ind < nbrows; ind++) {
					prevTotalLoad += (double)mpc.Get("bus", 1, 1).Get(2, ind + 1, 3);
				}

				// Line Below is from when running off-line, without HELICS
				// curr_time = curr_time + 1;
				next_Federate_time = fed->requestTime ((helics::Time) next_OPF_time);

				execution_time(tBefore, cBefore, "HELICS time request took ");

				if (next_Federate_time <= curr_time && curr_time != simStopTime) {
					LERROR << "HELICS returned a new time equal to or less than current sim time. Calling die!";
					fed->error(-1, "HELICS returned a new time equal to or less than current sim time. Calling die!");
					return -1;
				}

				LINFO << "*************************** TIMING TIMING TIMING *********************************";
				LINFO << "current time = " << curr_time;
				LINFO << "next opf time = " << next_OPF_time;
				LINFO << "GLD published, so MATPOWER jump at next time = " << next_Federate_time;
				LINFO << "**********************************************************************************";

				// setting current time for metric files
				mpLoadMetrics.setCurrentTimeBusValues(curr_time);
				mpGeneratorMetrics.setCurrentTimeBusValues(curr_time);
				curr_time = next_Federate_time;
			}
			while(curr_time < simStopTime);

			LINFO << "Let's write some MATPOWER metrics in JSON format.";
			mpLoadMetrics.jsonSave(loadMetricsFile);
			mpDispLoadMetrics.jsonSave(dispLoadMetricsFile);
			mpGeneratorMetrics.jsonSave(generatorMetricsFile);

			std::map<std::string, double>::iterator it = mapOfTimes.begin();
			while (it != mapOfTimes.end())
			{
				LMACTIME << it->first << it->second << " seconds (time)";
				LMACTIME << it->first << mapOfClock[it->first] / CLOCKS_PER_SEC << " seconds (clock)";
				it++;
			}

		}    
	  	catch (const mwException& e) {
			LERROR << "Caught an error!!!";
			cerr << e.what() << endl;
			cerr << "Terminating program..." << endl;
	        fed->error(-2, e.what());
	        return -2;
	  	}
	    catch (...) {
	    	LERROR << "Unexpected error thrown";
	    	auto expPtr = current_exception();
		    try
		    {
		        if(expPtr) rethrow_exception(expPtr);
		    }
		    catch(const exception& e) //it would not work if you pass by value
		    {
		         cerr << e.what() << endl;
		    }
			cerr << "Terminating program..." << endl;
	        fed->error(-3, "Unknown and unexpected error thrown");
	        return -3;
		}	

		LINFO << "Terminating Matlab libraries";
		libMATPOWERTerminate();
	}

	LINFO << "Terminating Matlab Compiler Runtime";
	mclTerminateApplication();
	LINFO << "Terminating HELICS federate";
	fed->finalize();
	return 0;
}

/* ==================================================================================================================
====================== MAIN PART ====================================================================================
===================================================================================================================*/
int main(int argc, char **argv) {
	// Setting up the logger based on user input
	char *log_level_export = NULL;
	log_level_export = getenv("MATPOWER_LOG_LEVEL");

	if (!log_level_export) {
		loglevel = logWARNING; 
	} else if (strcmp(log_level_export,"ERROR") == 0) {
		loglevel = logERROR;
	} else if (strcmp(log_level_export,"WARNING") == 0) {
		loglevel = logWARNING;
	} else if (strcmp(log_level_export,"INFO") == 0) {
		loglevel = logINFO;
	} else if (strcmp(log_level_export, "LMACTIME") == 0) {
		loglevel = logMACTIME;
	} else if (strcmp(log_level_export,"DEBUG") == 0) {
		loglevel = logDEBUG;
	} else if (strcmp(log_level_export,"DEBUG1") == 0) {
		loglevel = logDEBUG1;
	} else if (strcmp(log_level_export,"DEBUG2") == 0) {
		loglevel = logDEBUG2;
	} else if (strcmp(log_level_export,"DEBUG3") == 0) {
		loglevel = logDEBUG3;
	} else if (strcmp(log_level_export,"DEBUG4") == 0) {
		loglevel = logDEBUG4;
	}

	if (argc != 12 && argc != 13) {
		LERROR << "========================== ERROR ================================================";
		LERROR << "11 (simple T&D scenario) or 12 (TE scenario) arguments need to be provided:"; 
		LERROR << "HELICS configuration file, MATPOWER case file, real load profile file, ";
		LERROR << "reactive load profile file, simulation stop time (s), the market clear time (s), ";
		LERROR << "virtual market run time shift (s), the presumed starting time, and JSON output files";
		LERROR << "(for loads, generators, and dispatchable loads (for TE)), in this mentioned order.";
		LERROR << "There were " << argc - 1 << " arguments given!";
		LERROR << "=================================================================================";
		exit(EXIT_FAILURE);
	}
	if (argc == 13) {
		LINFO << "Running TE co-simulation for matpower federate -> " << argv[0];
		LINFO << "with JSON configuration file -> " << argv[1];
		LINFO << "with MATPOWER case -> " << argv[2];
		LINFO << "and daily real load profile -> " << argv[3];
		LINFO << "and daily reactive load profile -> " << argv[4];
		LINFO << "and daily renewable generation profile -> " << argv[5];
		LINFO << "for a market clearing time of " << argv[7] << " seconds,";
		LINFO << "with market calculations running " << argv[8] << "seconds before clearing, for synchronization due to communication delays,";
		LINFO << "and a total simulation time of " << argv[6] << " seconds.";
		LINFO << "starting on " << argv[9] << ", ";
		LINFO << "with load metrics in JSON format in file -> " << argv[10] << ", ";
		LINFO << "generator metrics in JSON format in file -> " << argv[11] << ", and ";
		LINFO << "dispatchable load (as negative generation) metrics in JSON format in file -> " << argv[12] << ".";
	}
	else {
		LINFO << "Running simple T&D co-simulation. Current federate -> " << argv[0];
		LINFO << "with JSON configuration file -> " << argv[1];
		LINFO << "with MATPOWER case -> " << argv[2];
		LINFO << "and daily real load profile -> " << argv[3];
		LINFO << "and daily reactive load profile -> " << argv[4];
		LINFO << "and daily renewable generation profile -> " << argv[5];
		LINFO << "for a market clearing time of " << argv[7] << " seconds,";
		LINFO << "with market calculations running " << argv[8] << "seconds before clearing, for synchronization due to communication delays,";
		LINFO << "and a total simulation time of " << argv[6] << " seconds.";
		LINFO << "starting on " << argv[9] << ", ";
		LINFO << "with load metrics in JSON format in file -> " << argv[10] << ", ";
		LINFO << "generator metrics in JSON format in file -> " << argv[11] << ", and ";
	}

	mclmcrInitialize();
	return mclRunMain((mclMainFcnType)run_main, argc, (const char**)argv);
}
