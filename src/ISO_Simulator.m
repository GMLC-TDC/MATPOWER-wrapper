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
% tnext_day_ahead_market = Wrapper.config_data.day_ahead_market.interval;
tnext_day_ahead_market = 0;

time_granted = 0;
next_helics_time =  min([tnext_physics_powerflow, tnext_real_time_market, tnext_day_ahead_market]);
    
%% Default Bid Configurations for Wrapper if HELICS is not Used. %%
price_range = [10, 30];
flexiblity = 0.25;
blocks = 10;

%% ISO Simulator Starts here
while time_granted <= Wrapper.duration

%     next_helics_time =  min([tnext_physics_powerflow, tnext_real_time_market, tnext_day_ahead_market]);
    next_helics_time =  min([tnext_day_ahead_market]);

    if Wrapper.config_data.include_helics
        time_granted  = helicsFederateRequestTime(Wrapper.helics_data.fed, next_helics_time);
%         fprintf('Wrapper: Requested  %ds in time and got Granted %d\n', next_helics_time, time_granted)
        fprintf('Wrapper: Current Time %s\n', (datetime(736543,'ConvertFrom','datenum') + seconds(time_granted)))
    else
        time_granted = next_helics_time;
        fprintf('Wrapper: Current Time %s\n', string(datetime(736543,'ConvertFrom','datenum') + seconds(time_granted)))
    end
    
    if (time_granted >= tnext_real_time_market) && (Wrapper.config_data.include_real_time_market)
            time_granted;
            Wrapper = Wrapper.update_loads_from_profiles(time_granted, 'load_profile_info', 'load_profile');
            Wrapper = Wrapper.update_VRE_from_profiles(time_granted, 'wind_profile_info', 'wind_profile');
            
            % Collect Bids from DSO
            if Wrapper.config_data.include_helics
                Wrapper = Wrapper.get_bids_from_helics();
            else
                Wrapper = Wrapper.get_bids_from_wrapper(time_granted, flexiblity, price_range, blocks);
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
    
    
    if (time_granted >= tnext_day_ahead_market) && (Wrapper.config_data.include_day_ahead_market)
        fprintf('Wrapper: Current Time %s\n', (datetime(736543,'ConvertFrom','datenum') + seconds(time_granted)))
        Wrapper = Wrapper.get_DA_forecast('wind_profile', time_granted, Wrapper.config_data.day_ahead_market.interval);
        Wrapper = Wrapper.get_DA_forecast('load_profile', time_granted, Wrapper.config_data.day_ahead_market.interval);
        
        gen_info = Wrapper.config_data.matpower_most_data.('wind_profile_info');
        gen_idx = gen_info.data_map.gen;
        data_idx = gen_info.data_map.columns;
        
        gen_struct = dam_gen_profiles(Wrapper.forecast.wind_profile, gen_idx, data_idx);
    
        load_info = Wrapper.config_data.matpower_most_data.('load_profile_info');
        load_idx = load_info.data_map.bus;
        data_idx = load_info.data_map.columns;
        load_struct = dam_load_profile(Wrapper.forecast.load_profile, load_idx, data_idx);

        profiles = getprofiles(gen_struct); 
        profiles = getprofiles(load_struct, profiles);
        mpc = Wrapper.mpc;
        mpc.gen(:, 17:20) = Inf;
        mpc.branch(:,6:8) = mpc.branch(:,6:8)*1.25;
        nt = size(profiles(1).values, 1);
        mdi = loadmd(mpc, nt, [], [], [], profiles);
        
        define_constants;
        % mpopt = mpoption('verbose', 3, 'out.all', 1, 'most.dc_model', 0, 'opf.dc.solver', 'GLPK');
        mpopt = mpoption('verbose', 1, 'out.all', 0, 'most.dc_model', 1);
        mdo = most(mdi, mpopt);
        ms = most_summary(mdo);
        % save('-text', 'msout.txt', 'ms');

        time = linspace(1, nt, nt);
        figure;
        a=subplot(2,1,1);
        set(a,'Units','normalized');
        plot(time, ms.Pg, '-','LineWidth',1.5)
        a=subplot(2,1,2);
        set(a,'Units','normalized');
        plot(time, ms.lamP,'-','LineWidth',1.5)
        
        figure;
        a=axes();
        set(a,'Units','normalized');
        plot(time, ms.Pd,'-','LineWidth',1.5)
        a =1;

        tnext_day_ahead_market = tnext_day_ahead_market + Wrapper.config_data.day_ahead_market.interval;
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
    
end

Wrapper.write_results(case_name)

if Wrapper.config_data.include_helics 
    helicsFederateDestroy(Wrapper.helics_data.fed)
    helics.helicsCloseLibrary()
end