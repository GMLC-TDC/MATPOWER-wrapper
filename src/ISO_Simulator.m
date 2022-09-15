clc
clear all
clear classes

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
    
% while time_granted <= Wrapper.config_data.Duration
price_range = [10, 30];
flexiblity = 0.2;

while time_granted <= 300
    next_helics_time =  min([tnext_physics_powerflow, tnext_real_time_market, tnext_day_ahead_market]);
    
    if Wrapper.config_data.include_helics
        time_granted  = helicsFederateRequestTime(Wrapper.helics_data.fed, next_helics_time);
        fprintf('Wrapper: Requested  %ds in time and got Granted %d\n', next_helics_time, time_granted)
    else
        time_granted = next_helics_time;
    end
    
    if (time_granted >= tnext_real_time_market) && (Wrapper.config_data.include_real_time_market)
            time_granted
            Wrapper = Wrapper.update_loads_from_profiles(time_granted, 'load_profile_info', 'load_profile');
            Wrapper = Wrapper.update_VRE_from_profiles(time_granted, 'wind_profile_info', 'wind_profile');
            [P_Q]  = Wrapper.get_bids_from_cosimulation(time_granted, flexiblity, price_range);
          %Wrapper = Wrapper.update_dispatchable_loads(bids)*************
          %Uses Wrapper, P_Q
            for i = 1 : length(Wrapper.config_data.cosimulation_bus)
                Bus_number = Wrapper.config_data.cosimulation_bus(i,1);
                Generator_index = size(Wrapper.mpc.gen,1) + 1;
                Wrapper.mpc.genfuel(Generator_index,:) = Wrapper.mpc.genfuel(1,:);  %copy random genfuel entry
                Wrapper.mpc.gen(Generator_index,:) = 0;                             %new entry of 0's
                Wrapper.mpc.gen(Generator_index,1) = Bus_number;                    %set bus #
                Wrapper.mpc.gen(Generator_index,6) = 1;  
                Wrapper.mpc.gen(Generator_index,8) = 1;                             %gen status on
%                 Wrapper.mpc.gen(Generator_index,7) = 0;
                Wrapper.mpc.gen(Generator_index,10) = -1*P_Q(Bus_number).range(2);  %Set reduction range
                Wrapper.mpc.gencost(Generator_index,:) = 0;                         %new entry of 0's
                Wrapper.mpc.gencost(Generator_index,1) = 2;                         %Polynomial model
                Wrapper.mpc.gencost(Generator_index,4) = 3;                         %Degree 3 polynomial
                Wrapper.mpc.gencost(Generator_index,5:7) = P_Q(Bus_number).bid;     %Polynomial coefficients
            end
            %*************************************************************
            Wrapper = Wrapper.run_RT_market(time_granted);
            %Update Bid loads*********************************************
            %Uses Wrapper
            for i = 1 : length(Wrapper.config_data.cosimulation_bus)
                Bus_number = Wrapper.config_data.cosimulation_bus(length(Wrapper.config_data.cosimulation_bus)-i+1,1);
                Generator_index = size(Wrapper.mpc.gen,1);
                Wrapper.mpc.bus(Bus_number,3) = Wrapper.mpc.bus(Bus_number,3) - Wrapper.mpc.gen(Generator_index,2);
                Wrapper.mpc.genfuel(Generator_index,:) = [];
                Wrapper.mpc.gen(Generator_index,:) = [];
                Wrapper.mpc.gencost(Generator_index,:) = [];
            end
            %*************************************************************
            tnext_real_time_market = tnext_real_time_market + Wrapper.config_data.real_time_market.interval;
    end
    
    if (time_granted >= tnext_physics_powerflow) && (Wrapper.config_data.include_physics_powerflow)     
            Wrapper = Wrapper.update_loads_from_profiles(time_granted, 'load_profile_info', 'load_profile');
            Wrapper = Wrapper.update_VRE_from_profiles(time_granted, 'wind_profile_info', 'wind_profile');
            
            if Wrapper.config_data.include_helics  
                Wrapper = Wrapper.update_loads_from_helics();
            end
            
            % Collect measurements from distribution networks
            Wrapper = Wrapper.run_power_flow(time_granted);  
            
            if Wrapper.config_data.include_helics  
                Wrapper = Wrapper.send_voltages_to_helics();
            end

            tnext_physics_powerflow = tnext_physics_powerflow + Wrapper.config_data.physics_powerflow.interval;
    end
    
    if time_granted == Wrapper.duration     %end infinite loop
        time_granted = Wrapper.duration+1;
    end

end

helicsFederateDestroy(Wrapper.helics_data.fed)
helics.helicsCloseLibrary()