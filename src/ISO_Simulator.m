clc
clear all
clear classes
warning('off','MATLAB:polyfit:RepeatedPointsOrRescale');

case_name = 'Poly25';
%% Check if MATLAB or OCTAVE
isOctave = exist('OCTAVE_VERSION', 'builtin') ~= 0;
%% Load Model
wrapper_startup;
Wrapper = MATPOWERWrapper('wrapper_config.json', isOctave);

%% Read profile and save it within a strcuture called load
Wrapper = Wrapper.read_profiles('load_profile_info', 'load_profile');
Wrapper = Wrapper.read_profiles('wind_profile_info', 'wind_profile');

if Wrapper.config_data.include_helics

    if isOctave
       helics; 
    else
       import helics.*
    end
               
    Wrapper = Wrapper.prepare_helics_config('helics_config.json', 'DSOSim'); 
    Wrapper = Wrapper.start_helics_federate('helics_config.json');
end
    
tnext_physics_powerflow = Wrapper.config_data.physics_powerflow.interval;
tnext_real_time_market = Wrapper.config_data.real_time_market.interval;
tnext_day_ahead_market = Wrapper.config_data.day_ahead_market.interval;

time_granted = 0;
next_helics_time =  min([tnext_physics_powerflow, tnext_real_time_market, tnext_day_ahead_market]);
    

price_range = [10, 30];
flexiblity = 0.25;
blocks = 10;

while time_granted <= Wrapper.duration
    next_helics_time =  min([tnext_physics_powerflow, tnext_real_time_market]);
    if Wrapper.config_data.include_helics
        time_granted  = helicsFederateRequestTime(Wrapper.helics_data.fed, next_helics_time);
        fprintf('Wrapper: Requested  %ds in time and got Granted %d\n', next_helics_time, time_granted)
    else
        time_granted = next_helics_time;
        fprintf('Wrapper: Current Time %d\n', time_granted)
    end
    
    if (time_granted >= tnext_real_time_market) && (Wrapper.config_data.include_real_time_market)
            time_granted;
            Wrapper = Wrapper.update_loads_from_profiles(time_granted, 'load_profile_info', 'load_profile');
            Wrapper = Wrapper.update_VRE_from_profiles(time_granted, 'wind_profile_info', 'wind_profile');
            
            % Collect Bids from DSO
            if Wrapper.config_data.include_helics
                Wrapper = Wrapper.get_bids_from_helics();
            else
                Wrapper = Wrapper.get_bids_from_cosimulation(time_granted, flexiblity, price_range, blocks);
            end
            
            %*************************************************************
            Wrapper = Wrapper.run_RT_market(time_granted);
            %***********************************************************
            
            %*************************************************************
            % Collect Allocations from DSO
            if Wrapper.config_data.include_helics
                Wrapper = Wrapper.send_allocations_to_helics();
            end
            
            tnext_real_time_market = tnext_real_time_market + Wrapper.config_data.real_time_market.interval;
    end
    
    if (time_granted >= tnext_physics_powerflow) && (Wrapper.config_data.include_physics_powerflow)     
            Wrapper = Wrapper.update_loads_from_profiles(time_granted, 'load_profile_info', 'load_profile');
            Wrapper = Wrapper.update_VRE_from_profiles(time_granted, 'wind_profile_info', 'wind_profile');
            
            % Collect measurements from distribution networks
            if Wrapper.config_data.include_helics  
                Wrapper = Wrapper.get_loads_from_helics();
            end
            %*************************************************************
            Wrapper = Wrapper.run_power_flow(time_granted);  
            %*************************************************************
            % Send Voltages from distribution networks
            if Wrapper.config_data.include_helics  
                Wrapper = Wrapper.send_voltages_to_helics();
            end

            tnext_physics_powerflow = tnext_physics_powerflow + Wrapper.config_data.physics_powerflow.interval;
    end
    
    if time_granted == Wrapper.duration     %end infinite loop
        time_granted = Wrapper.duration+1;
    end

end

Wrapper.write_results(case_name)

if Wrapper.config_data.include_helics 
    helicsFederateDestroy(Wrapper.helics_data.fed)
    helics.helicsCloseLibrary()
end