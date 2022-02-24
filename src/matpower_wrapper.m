 function matpower_wrapper()
   config_file = 'wrapper_config.json';
   
   %%%%%%%%%%%%%%%%%%%%%%%%%%% Loading Packages %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
   startup;
   pkg load json ;
   pkg load slf4o;
   logger.initSLF4O
   helics;
   logger.info('Loading packages');
   logger.info('HELICS Version %s', helicsGetVersion());
   functions = wrapper_functions;
   
   %%%%%%%%%%%%%%%%%%%%%%% Reading Configuration %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
   config_data = functions.read_config(config_file);
   logger.info('Loading Simulation Configuration File %s',config_file);

   %%%%%%%%%%%%%%%%%%%%%%%%% Setting up MATPOWER-MOST %%%%%%%%%%%%%%%%%%%%%%%%%%
   start_time = strptime(config_data.start_time, '%Y-%m-%d %k:%M:%S');
   end_time = strptime(config_data.end_time, '%Y-%m-%d %k:%M:%S');
   config_data.Duration = mktime(end_time) - mktime (start_time);
   logger.info('Simulation Duration: %d', config_data.Duration);
   case_name = strcat(config_data.matpower_most_data.datapath, config_data.matpower_most_data.case_name);
   if isempty(regexp (case_name,'.json'))
     mpc = loadcase(case_name) ### Load in built MATPOWER CASE
   else
     mpc = functions.read_config(case_name);
   end
   logger.info('Transmission System: %s', config_data.matpower_most_data.case_name);

   if isfield(config_data.matpower_most_data,'load_profile')
     load_profile_file_name = strcat(config_data.matpower_most_data.datapath, config_data.matpower_most_data.load_profile.filename);     
     logger.info('Loading Load profiles for system from: %s', config_data.matpower_most_data.load_profile.filename);
     case_profiles = functions.create_profiles(load_profile_file_name, config_data.matpower_most_data.load_profile, start_time, end_time, config_data.physics_powerflow.interval, config_data.Duration);
   else
     logger.info('Not Loading any profiles');
   end
   

   %%%%%%%%%%%%%%%%%%%%%%%%% Setting up HELICS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%   
   cosim_bus_to_remove = config_data.cosimulation_bus(mpc.bus(config_data.cosimulation_bus,2) == 3);
   if ~isempty(cosim_bus_to_remove)
     logger.warn('Cosimulation bus %s is not allocated to a PQ/PV bus: Discarding', mat2str(cosim_bus_to_remove));
     config_data.cosimulation_bus = setdiff(config_data.cosimulation_bus, cosim_bus_to_remove);
   end
   logger.info('Creating HELICS configuration file: %s', 'wrapper_helics_config.json');
   config_data = functions.prepare_helics_config('wrapper_helics_config.json', config_data);   
   functions.write_config('wrapper_helics_config.json', config_data.helics_config); 
   
##   fed = helicsCreateValueFederateFromConfig('wrapper_helics_config.json');
##   federate_name = helicsFederateGetName(fed)
   
   tnext_physics_powerflow = config_data.physics_powerflow.interval;
   tnext_real_time_market = config_data.real_time_market.interval;
   tnext_day_ahead_market = config_data.day_ahead_market.interval;
   time_granted = 0;
   next_helics_time =  min([tnext_physics_powerflow, tnext_real_time_market, tnext_day_ahead_market]);
   
   
endfunction


  