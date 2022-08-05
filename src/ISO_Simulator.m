clc
clear all
clear classes

%% Load Model
Wrapper = MATPOWERWrapper('wrapper_config.json');

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
%             Collect_bids
%             Wrapper = Wrapper.update_dispatchable_loads(bids)
            Wrapper = Wrapper.run_RT_market(time_granted, mpoptOPF);      
            tnext_real_time_market = tnext_real_time_market + Wrapper.config_data.real_time_market.interval;
    end
    
    if time_granted >= tnext_physics_powerflow        
            Wrapper = Wrapper.update_loads_from_profiles(time_granted, 'load_profile_info', 'load_profile');
            Wrapper = Wrapper.update_VRE_from_profiles(time_granted, 'wind_profile_info', 'wind_profile');
            % Collect measurements from distribution networks
            Wrapper = Wrapper.run_power_flow(time_granted, mpoptPF);    
            tnext_physics_powerflow = tnext_physics_powerflow + Wrapper.config_data.physics_powerflow.interval;
    end
    
end

    