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
Wrapper = Wrapper.prepare_helics_config('helics_config.json');   
    
tnext_physics_powerflow = Wrapper.config_data.physics_powerflow.interval;
tnext_real_time_market = Wrapper.config_data.real_time_market.interval;
tnext_day_ahead_market = Wrapper.config_data.day_ahead_market.interval;
time_granted = 0;
next_helics_time =  min([tnext_physics_powerflow, tnext_real_time_market, tnext_day_ahead_market]);
    
mpoptOPF = mpoption('verbose', 0, 'out.all', 0, 'model', 'DC');
mpoptPF = mpoption('verbose', 0, 'out.all', 0, 'pf.nr.max_it', 20, 'pf.enforce_q_lims', 0, 'model', 'DC');
    
    %% Increasing the branch 
    
% while time_granted <= Wrapper.config_data.Duration
price_range = [10, 30];
flexiblity = 0.2;

while time_granted <= Wrapper.duration
    next_helics_time =  min([tnext_physics_powerflow, tnext_real_time_market, tnext_day_ahead_market]);
    time_granted = next_helics_time;
%     mpc.bus(:,12) = 1.3* ones(length(mpc.bus(:,12)),1);
%     mpc.bus(:,13) = 0.7* ones(length(mpc.bus(:,13)),1);
%     mpc.gen(:,4) = mpc.gen(:,7);
%     mpc.gen(:,5) = -1*mpc.gen(:,7);
    
    
    if time_granted >= tnext_real_time_market  
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
            Wrapper = Wrapper.run_RT_market(time_granted, mpoptOPF);
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
    
    if time_granted >= tnext_physics_powerflow        
            Wrapper = Wrapper.update_loads_from_profiles(time_granted, 'load_profile_info', 'load_profile');
            Wrapper = Wrapper.update_VRE_from_profiles(time_granted, 'wind_profile_info', 'wind_profile');
            % Collect measurements from distribution networks
            Wrapper = Wrapper.run_power_flow(time_granted, mpoptPF);    
            tnext_physics_powerflow = tnext_physics_powerflow + Wrapper.config_data.physics_powerflow.interval;
    end
    
    if time_granted == Wrapper.duration     %end infinite loop
        time_granted = Wrapper.duration+1;
    end

end

    