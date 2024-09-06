clc
clear all
clear classes
warning('off','MATLAB:polyfit:RepeatedPointsOrRescale');
tic();
% UCBase, UCStor, UCFlex10, UCFlex20, UCMis10, UCMis20
case_name = 'Test';  %Base, Flex10, Flex20, Mis10, Mis20
DAM_plot_option = 0;
stor = struct();
stor.state = 0;
flag_uc = 1;
Mismatch = 0;
flex = 0;


%% Check if MATLAB or OCTAVE
isOctave = exist('OCTAVE_VERSION', 'builtin') ~= 0;
%% Load Model
wrapper_startup;
Wrapper = MATPOWERWrapper('wrapper_config_test.json', isOctave);
storage_option = Wrapper.config_data.include_storage;   %In wrapper_config

%% Read profile and save it within a strcuture called load
if isOctave
    src_dir = prev_dir();
end
Wrapper = Wrapper.read_profiles('load_profile_info', 'load_profile');
Wrapper = Wrapper.read_profiles('wind_profile_info', 'wind_profile');

if isOctave
    cd(src_dir);
end

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
tnext_day_ahead_market = 5;

time_granted = 0;
next_helics_time =  min([tnext_physics_powerflow, tnext_real_time_market, tnext_day_ahead_market]);

%% Updating the FLow Limits %%
Wrapper.MATPOWERModifier = Wrapper.MATPOWERModifier.modify_line_limits(1:8, 0.5);
Wrapper.MATPOWERModifier = Wrapper.MATPOWERModifier.modify_line_limits(7, 3);
Wrapper =  Wrapper.update_model(); % Do this to get the new limits into the the mpc structure

%% Adding Zonal Reserves %%
res_zones = Wrapper.mpc.bus(:, 11);
max_zonal_loads =  [71590]; % Test Case Based on 2016 data
% Assuming reserve requirement to be 7 % of peak load
zonal_res_req = max_zonal_loads'*7.0/100; 

% assuming Non VRE generators to participate in reserve allocations
Wrapper.reserve_genId = [1:13]; %% Test case
% assuming 10% reserve availiability from all generators
reserve_genQ = Wrapper.mpc.gen(Wrapper.reserve_genId, 9)* 10/100;
% assuming constant price for reserves from all generators
reserve_genP = 15*ones(length(Wrapper.reserve_genId), 1);


Wrapper.MATPOWERModifier = Wrapper.MATPOWERModifier.add_zonal_reserves(Wrapper.reserve_genId, reserve_genQ, reserve_genP, zonal_res_req);
Wrapper =  Wrapper.update_model(); % Do this to get reserves into the the mpc structure

%% Default Bid Configurations for Wrapper if HELICS is not Used. %%
bid_blocks = 5;
price_range = [10, 20];
flex_max = flex ; % Defines maximum flexibility as a % of total load
if ~isOctave
  flex_profile = unifrnd(0,flex_max,[24,1])/100;
end
flex_profile = flex_max*ones(24, 1)/100;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%  Mismatch runs %%%%%%%%%%%%%%%%%%%%%%%%%%%%
if Mismatch
    flex_profile_DAM = zeros(24,1);
else
    flex_profile_DAM = flex_profile;
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


tStart = tic;   
%% ISO Simulator Starts here
while time_granted < Wrapper.duration
     
    next_helics_time = Wrapper.duration;
    if Wrapper.config_data.include_day_ahead_market
        next_helics_time = min([tnext_day_ahead_market, next_helics_time]);
    end
    if Wrapper.config_data.include_real_time_market
        next_helics_time = min([tnext_real_time_market, next_helics_time]);
    end
    if Wrapper.config_data.include_physics_powerflow
        next_helics_time = min([tnext_physics_powerflow, next_helics_time]);
    end
     

    if Wrapper.config_data.include_helics
        time_granted  = helicsFederateRequestTime(Wrapper.helics_data.fed, next_helics_time);
        % fprintf('Wrapper: Requested  %ds in time and got Granted %d\n', next_helics_time, time_granted)
    else
        time_granted = next_helics_time;
    end

    current_time = datestr(datenum(Wrapper.config_data.start_time) + (time_granted/86400));
    fprintf('Wrapper: Current Time %s\n', current_time)
    
    
    %% *************************************************************
    %% Running Physics based Power Flow
    %% *************************************************************
    if (time_granted >= tnext_physics_powerflow) && (Wrapper.config_data.include_physics_powerflow)     
        Wrapper = Wrapper.update_loads_from_profiles(time_granted, 'load_profile_info', 'load_profile');
        if isfield(Wrapper.profiles,'wind_profile')
            Wrapper = Wrapper.update_VRE_from_profiles(time_granted, 'wind_profile_info', 'wind_profile');
        end
        if isfield(Wrapper.profiles,'solar_profile')
            Wrapper = Wrapper.update_VRE_from_profiles(time_granted, 'solar_profile_info', 'solar_profile');
        end
        % Collect measurements from distribution networks
        if Wrapper.config_data.include_helics  
            Wrapper = Wrapper.get_loads_from_helics();
        end
        
        fprintf('Wrapper: Running Power Flow at Time %s\n', (datestr(datenum(Wrapper.config_data.start_time) + (time_granted/86400))))
        %*************************************************************
        Wrapper = Wrapper.run_power_flow(time_granted);  
        %*************************************************************
        % Send Voltages from distribution networks
        if Wrapper.config_data.include_helics  
            Wrapper = Wrapper.send_voltages_to_helics();
        end
        if tnext_physics_powerflow < Wrapper.config_data.physics_powerflow.interval
            tnext_physics_powerflow = Wrapper.config_data.physics_powerflow.interval;
        else
            tnext_physics_powerflow = tnext_physics_powerflow + Wrapper.config_data.physics_powerflow.interval;
        end
    end
    
    
    %% *************************************************************
    %% Running Day Ahead Energy Arbitrage Market
    %% ************************************************************* 
    
    if (time_granted >= tnext_day_ahead_market) && (Wrapper.config_data.include_day_ahead_market) && (time_granted < Wrapper.duration)

        if time_granted < 86400
            time_granted = 0;
        end

        fprintf('Wrapper: DA forecast at Time %s\n', datestr(datenum(Wrapper.config_data.start_time) + (time_granted/86400)))
        Wrapper = Wrapper.get_DA_forecast('load_profile', time_granted, Wrapper.config_data.day_ahead_market.interval);

        if isfield(Wrapper.config_data.matpower_most_data,'wind_profile_info')
            Wrapper = Wrapper.get_DA_forecast('wind_profile', time_granted, Wrapper.config_data.day_ahead_market.interval);
        end
        
        if isfield(Wrapper.config_data.matpower_most_data,'solar_profile_info')
            Wrapper = Wrapper.get_DA_forecast('solar_profile', time_granted, Wrapper.config_data.day_ahead_market.interval);
        end

        
        %% Getting DAM bids from Co-simulation %%
        if Wrapper.config_data.include_helics
                Wrapper = Wrapper.get_DAM_bids_from_helics();
        else
                Wrapper = Wrapper.get_DAM_bids_from_wrapper(time_granted, flex_profile_DAM, price_range, bid_blocks);
        end
            
        Wrapper.mustrun_genId = [10:18]; ; %% Nuclear + VRE        
        fprintf('Wrapper: Running DA Market at Time %s\n', (datestr(datenum(Wrapper.config_data.start_time) + (time_granted/86400))))
        Wrapper = Wrapper.run_DA_market(flag_uc, time_granted);

        if DAM_plot_option
            time = linspace(1, 24, 24);
            figure;
            a1=subplot(2,1,1);
            set(a1,'Units','normalized');
            plot(time, Wrapper.DAM_summary.Pg, '-','LineWidth',1.5)
            ylabel(a1,'DA-PG ($/MWHr)','FontSize',12);
            xlabel(a1,'Time of Day (Hr)','FontSize',12)
            a2=subplot(2,1,2);
            set(a2,'Units','normalized');
            plot(time, Wrapper.DAM_summary.lamP,'-','LineWidth',1.5)
            ylabel(a2,'DA-LMP ($/MWHr)','FontSize',12);
            xlabel(a2,'Time of Day (Hr)','FontSize',12)
            
            figure;
            a=axes();
            set(a,'Units','normalized');
            plot(time, Wrapper.DAM_summary.Pd,'-','LineWidth',1.5)
            ylabel(a,'Bus-Demand (MWH)','FontSize',12);
            xlabel(a,'Time of Day (Hr)','FontSize',12)
            a=1;
        end

        if tnext_day_ahead_market < 86400
            tnext_day_ahead_market = Wrapper.config_data.day_ahead_market.interval;
        else
            tnext_day_ahead_market = tnext_day_ahead_market + Wrapper.config_data.day_ahead_market.interval;
        end
        fprintf('Wrapper: NEXT DAM at Time %s\n', (tnext_day_ahead_market))

        
    end
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%% Create Storage Profile %%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    if storage_option && Wrapper.config_data.include_day_ahead_market
        DA_RT_ratio = 3600 / Wrapper.config_data.real_time_market.interval;
        RT_intervals = (size(Wrapper.results.DAM.PG,1)*DA_RT_ratio-1);
        storage_profile = zeros(length(st_data.UnitIdx),RT_intervals);
        for i=1:length(st_data.UnitIdx)
            for a = 1:RT_intervals
                storage_profile(i,a) = Wrapper.results.DAM.PG(floor((a-1)/DA_RT_ratio)+1,st_data.UnitIdx(i)+1);
            end
        end
    end

    %% *************************************************************
    %% Running Real Time Energy Imbalance Market
    %% *************************************************************    
    if (time_granted >= tnext_real_time_market) && (Wrapper.config_data.include_real_time_market) && (time_granted < Wrapper.duration)
            time_granted = time_granted - mod(time_granted,Wrapper.config_data.real_time_market.interval);
            time_granted;
            Wrapper = Wrapper.update_loads_from_profiles(time_granted, 'load_profile_info',  'load_profile');
           
            if isfield(Wrapper.config_data.matpower_most_data,'wind_profile_info')
                Wrapper = Wrapper.update_VRE_from_profiles(time_granted,   'wind_profile_info',  'wind_profile');
            end        
            if isfield(Wrapper.config_data.matpower_most_data,'solar_profile_info')
                Wrapper = Wrapper.update_VRE_from_profiles(time_granted,   'solar_profile_info', 'solar_profile');
            end
        

            %% Storage Profile %%
            if storage_option && Wrapper.config_data.include_day_ahead_market
                % Add Storage back in
                Wrapper.mpc.gen(st_data.UnitIdx,:) = stor.gen;
                Wrapper.mpc.gencost(st_data.UnitIdx,:) = stor.gencost;
                Wrapper.mpc.genfuel(st_data.UnitIdx,:) = stor.genfuel;
                
                for i=1:length(st_data.UnitIdx)
                    if mod(time_granted, 86400) ~= 0
                        Wrapper.mpc.gen(st_data.UnitIdx(i),2) = storage_profile(i,time_granted/Wrapper.config_data.real_time_market.interval);
                        Wrapper.mpc.gen(st_data.UnitIdx(i),9) = storage_profile(i,time_granted/Wrapper.config_data.real_time_market.interval);
                        Wrapper.mpc.gen(st_data.UnitIdx(i),10)= storage_profile(i,time_granted/Wrapper.config_data.real_time_market.interval);
                    else
                        Wrapper.mpc.gen(st_data.UnitIdx(i),2) = storage_profile(i,time_granted/Wrapper.config_data.real_time_market.interval-1);
                        Wrapper.mpc.gen(st_data.UnitIdx(i),9) = storage_profile(i,time_granted/Wrapper.config_data.real_time_market.interval-1);
                        Wrapper.mpc.gen(st_data.UnitIdx(i),10)= storage_profile(i,time_granted/Wrapper.config_data.real_time_market.interval-1);
                    end
                end
            end
            %%%%%%%%%%%%%%%%%%%%%
            
            if isOctave
              hod = floor(24 * (datenum(current_time) - floor(datenum(current_time)))) + 1;
            else
              hod = hour(datetime(current_time))+1;
            end
            % Collect Bids from DSO
            if Wrapper.config_data.include_helics
                Wrapper = Wrapper.get_RTM_bids_from_helics();
            else
                Wrapper = Wrapper.get_RTM_bids_from_wrapper(time_granted, flex_profile(hod), price_range, bid_blocks);
            end
            if Wrapper.config_data.include_day_ahead_market
                hour_idx = floor((time_granted)/3600) + 1;
                Wrapper.mpc.gen(:,8) = transpose(Wrapper.results.DAM.UC(hour_idx,2:(size(Wrapper.mpc.gen,1)+1)));
                % Wrapper.mpc.gen(:,8) = ones(size(Wrapper.mpc.gen,1),1);
            end
            
            fprintf('Wrapper: Running RT Market at Time %s\n', (datestr(datenum(Wrapper.config_data.start_time) + (time_granted/86400))))
            %***********************************************************%
            Wrapper = Wrapper.run_RT_market(time_granted);
            %***********************************************************%
            
            %***********************************************************%
            % Collect Allocations from DSO
            if Wrapper.config_data.include_helics
                Wrapper = Wrapper.send_RTM_allocations_to_helics();
            end
            if tnext_real_time_market < Wrapper.config_data.real_time_market.interval
                tnext_real_time_market = Wrapper.config_data.real_time_market.interval;
            else
                tnext_real_time_market = tnext_real_time_market + Wrapper.config_data.real_time_market.interval;
            end
            tnext_real_time_market = tnext_real_time_market - mod(tnext_real_time_market,Wrapper.config_data.real_time_market.interval);
    end
end

Wrapper.write_results(case_name)

if Wrapper.config_data.include_helics 
    helicsFederateDestroy(Wrapper.helics_data.fed)
    helics.helicsCloseLibrary()
end

sec=toc();
fprintf('Wrapper: %0.2f minutes taken to run the example \n', (sec/60))