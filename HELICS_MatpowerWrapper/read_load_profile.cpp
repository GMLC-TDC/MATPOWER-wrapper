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

void read_load_profile(char *file_name, vector< vector<double> > &load_profile, int subst_num, int readings_num)
{
	ifstream data_file(file_name, ios::in);
	try {
	   if (data_file.is_open()){
			LINFO << "======== Starting reading from file -> " << file_name << " for " << subst_num << "x" << readings_num << " matrix." ;
			
			for (int j = 0; j < subst_num; j++){
				for (int i = 0; i < readings_num; i++){
					if (!data_file.eof()) {
						data_file >> load_profile[j][i]; // extracts and parses characters sequentially from the stream created from the data file, 
														 // to interpret them as the representation of a value of the proper type, given by the type of load_profile, that is float
						LDEBUG4 << "Row-> " << j+1 << " Column-> " << i+1 << " Value-> " << load_profile[j][i];
					}
					else {
						LDEBUG4 << "Row-> " << j+1 << " Column-> " << i+1;
						throw 225;
					}
				}
			} 

			if (data_file.eof()) {
				//LDEBUG << "Reached the end of the file!!!!!!!!" ;
				LINFO << "======== Finished reading from file -> " << file_name;
				data_file.close();
			}	
			else {
				data_file.close();
				throw 226;
			}
			
	   }
	   else {
		  throw 227;	  
	   }
	}
   catch (int e) {
		if (e == 225) {
			LERROR << "Reached end of file too early" ;
		}
		else if (e == 226) {
			LERROR << "Did not reach end of file after completing load profiles" ;	
		}
		else if (e == 227) {
			LERROR << "Unable to open load profile file." ;	
		}
		else {
			LERROR << "Unknown error while reading the load profiles!!!!!!!!" ;
		}
	    
	 exit(EXIT_FAILURE);
   }
} // END OF get_load_profile function
