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
flag_600_gen = 1;
flag_18_gen = 0;
flag_uc = 0;
Mismatch = 0;
flex = 0;

flag_reduce_gen = 0;
flag_reduce_option = 1; % 0 reduces by cost, 1 reduces by capacity
gen_goal = 400; % How many generators to run with UC (<=422)
% Ex: 0, 20: only the 20 most expensive generators can be decommitted
% Ex: 1, 30: only the 30 smallest generators can be decommitted

%% Check if MATLAB or OCTAVE
isOctave = exist('OCTAVE_VERSION', 'builtin') ~= 0;
%% Load Model
wrapper_startup;
if flag_600_gen
    Wrapper = MATPOWERWrapper('wrapper_config_v2.json', isOctave);
elseif flag_18_gen
    Wrapper = MATPOWERWrapper('wrapper_config_test.json', isOctave);
else
    Wrapper = MATPOWERWrapper('wrapper_config.json', isOctave);
end

storage_option = Wrapper.config_data.include_storage;   %In wrapper_config
% Wrapper = MATPOWERWrapper('wrapper_config_test.json', isOctave);
%% Read profile and save it within a strcuture called load
if isOctave
    src_dir = prev_dir();
end
Wrapper = Wrapper.read_profiles('load_profile_info', 'load_profile');
Wrapper = Wrapper.read_profiles('wind_profile_info', 'wind_profile');
if flag_600_gen
    Wrapper = Wrapper.read_profiles('solar_profile_info', 'solar_profile');
end

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

define_constants;
tnext_physics_powerflow = Wrapper.config_data.physics_powerflow.interval;
tnext_real_time_market = Wrapper.config_data.real_time_market.interval;
% tnext_day_ahead_market = Wrapper.config_data.day_ahead_market.interval;
tnext_day_ahead_market = 5;

time_granted = 0;
next_helics_time =  min([tnext_physics_powerflow, tnext_real_time_market, tnext_day_ahead_market]);

%% Updating the FLow Limits %%

if flag_600_gen == 1
    reduction = 0.7;
    Wrapper.MATPOWERModifier = Wrapper.MATPOWERModifier.modify_line_limits(1:13, reduction); %Reduce for line limits
    Wrapper.MATPOWERModifier = Wrapper.MATPOWERModifier.modify_line_limits(8, 1.4); %vital line
    Wrapper.MATPOWERModifier = Wrapper.MATPOWERModifier.modify_line_limits(12, 1.4); %vital line
    Wrapper.MATPOWERModifier = Wrapper.MATPOWERModifier.modify_line_limits(4:7, 0.95);       % 2-1
%     Wrapper.MATPOWERModifier = Wrapper.MATPOWERModifier.modify_line_limits(5, 0.91);       % 2-7
    Wrapper.MATPOWERModifier = Wrapper.MATPOWERModifier.modify_line_limits(9:11, 0.925);       % 2-5
else
    Wrapper.MATPOWERModifier = Wrapper.MATPOWERModifier.modify_line_limits(1:8, 0.5);
    Wrapper.MATPOWERModifier = Wrapper.MATPOWERModifier.modify_line_limits(7, 3);
end
Wrapper =  Wrapper.update_model(); % Do this to get the new limits into the the mpc structure

%% Adding Zonal Reserves %%
res_zones = Wrapper.mpc.bus(:, 11);
max_zonal_loads =  [19826.18, 25282.32, 19747.12, 6694.77]; % Based on 2016 data
if flag_18_gen
    max_zonal_loads = sum(max_zonal_loads);
    max_zonal_loads =  [71590]; % Test Case Based on 2016 data
end
% max_zonal_loads =  [71590]; % Test Case Based on 2016 data
% Assuming reserve requirement to be 2 % of peak load
zonal_res_req = max_zonal_loads'*5.0/100; 
if flag_18_gen
    zonal_res_req = max_zonal_loads'*1.0/100;
end
% assuming Non VRE generators to participate in reserve allocations
if flag_600_gen == 1
    %% 600 Gen Case %%
    Wrapper.reserve_genId = [];
    Wrapper.mustrun_genId = [];
    if flag_reduce_gen && flag_uc
        reduce_list = [];
        reduced_gens = 0;
        for gen_idx = 1:length(Wrapper.mpc.genfuel)
            if Wrapper.mpc.genfuel(gen_idx) ~=  "hydro"  && Wrapper.mpc.genfuel(gen_idx) ~=  "solar" && ... 
                Wrapper.mpc.genfuel(gen_idx) ~=  "wind" && Wrapper.mpc.genfuel(gen_idx) ~=  "nuclear" 
                if flag_reduce_option == 1
                    reduce_list = [reduce_list;gen_idx,Wrapper.mpc.gen(gen_idx,9)];
                else
                    reduce_list = [reduce_list;gen_idx,Wrapper.mpc.gencost(gen_idx,6)];
                end
            else
                reduced_gens = reduced_gens + 1;
            end
        end
        if flag_reduce_option == 1
            [~,reduce_index] = sort(reduce_list(:,2),'descend'); % Largest generators must run
        else
            [~,reduce_index] = sort(reduce_list(:,2),'ascend'); % Cheapest generators must run
        end
        reduce_order = reduce_list(reduce_index,1);
        reduce_order = reduce_order(1:(length(Wrapper.mpc.gen)-reduced_gens-gen_goal));
    end
    if flag_uc && flag_reduce_gen
        remaining_gen = length(reduce_list);
    end
    for gen_idx = 1:length(Wrapper.mpc.genfuel)
        if Wrapper.mpc.genfuel(gen_idx) ==  "nuclear" ||  Wrapper.mpc.genfuel(gen_idx) ==  "coal" || Wrapper.mpc.genfuel(gen_idx) ==  "ng" 
            Wrapper.reserve_genId = [Wrapper.reserve_genId gen_idx];
        end
        if Wrapper.mpc.genfuel(gen_idx) ==  "hydro"  || Wrapper.mpc.genfuel(gen_idx) ==  "solar" || ... 
                Wrapper.mpc.genfuel(gen_idx) ==  "wind" || Wrapper.mpc.genfuel(gen_idx) ==  "nuclear" 
            Wrapper.mustrun_genId = [Wrapper.mustrun_genId gen_idx];
        elseif flag_reduce_gen && flag_uc
            if ismember(gen_idx,reduce_order) %Will add to must run based on preference flag_reduce_cap
                Wrapper.mustrun_genId = [Wrapper.mustrun_genId gen_idx];
            end
        end
    end
    if flag_reduce_gen && flag_uc
        remaining_gen = length(Wrapper.mpc.genfuel) - length(Wrapper.mustrun_genId);
    end
elseif ~flag_18_gen
    Wrapper.reserve_genId = [1:33]; %% 100 Gen case
    Wrapper.mustrun_genId = [75:110]; 
else
    Wrapper.reserve_genId = [1:13]; %% Test case
end
% assuming 5% reserve availiability from all generators
% reserve_genQ = Wrapper.mpc.gen(Wrapper.reserve_genId, 9)* 15/100; 
reserve_genQ = Wrapper.mpc.gen(Wrapper.reserve_genId, 9)* 15/100;

% assuming constant price for reserves from all generators
reserve_genP = 15*ones(length(Wrapper.reserve_genId), 1);
reserve_genP = 1*ones(length(Wrapper.reserve_genId), 1);


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



%%%%%%%%%%%%%%%%%%%%%%% Adding storage %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% if storage_option
%     if Wrapper.config_data.include_helics
%         % storage_specs = read_json("storage_config.json");
%         % pause(1);
%         Wrapper = get_storage_from_helics(Wrapper);
%         storage_specs = Wrapper.storage_specs;
%     else
%         storage_specs = read_json("storage_config.json");
%     end
%     [~,Wrapper.mpc,~,st_data] = addstorage(storage_custom(storage_specs),Wrapper.mpc);
%     stor = storage_custom(storage_specs);
% 
% end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

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
     
    % next_helics_time =  min([tnext_physics_powerflow, tnext_real_time_market, tnext_day_ahead_market]);
    % next_helics_time =  min([tnext_day_ahead_market]);

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
        Wrapper = Wrapper.update_VRE_from_profiles(time_granted, 'wind_profile_info', 'wind_profile');
        Wrapper = Wrapper.update_VRE_from_profiles(time_granted, 'solar_profile_info', 'solar_profile');
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
%         fprintf('Wrapper: Current Time %s\n', (datetime(736543,'ConvertFrom','datenum') + seconds(time_granted)))
%         fprintf('Wrapper: DA forecast at Time %s\n', (datetime(Wrapper.config_data.start_time) + seconds(time_granted)))
        if time_granted < 86400
            time_granted = 0;
        end
        fprintf('Wrapper: DA forecast at Time %s\n', datestr(datenum(Wrapper.config_data.start_time) + (time_granted/86400)))
        Wrapper = Wrapper.get_DA_forecast('wind_profile', time_granted, Wrapper.config_data.day_ahead_market.interval);
        Wrapper = Wrapper.get_DA_forecast('load_profile', time_granted, Wrapper.config_data.day_ahead_market.interval);
        
        if flag_600_gen
            Wrapper = Wrapper.get_DA_forecast('solar_profile', time_granted, Wrapper.config_data.day_ahead_market.interval);
        end


        %% Clearing storage %%
        % if storage_option
        %     Wrapper.mpc.gen(st_data.UnitIdx,:) = stor.gen;
        % end

        %% Adding Generation Profiles from forecast for VRE-based Generators %%
        gen_info = Wrapper.config_data.matpower_most_data.('wind_profile_info');
        gen_idx = gen_info.data_map.gen;
        data_idx = gen_info.data_map.columns;
        % gen_profile = dam_gen_profiles(Wrapper.forecast.wind_profile, gen_idx, data_idx); 
        VRE_wind_profile = create_dam_profile(Wrapper.forecast.wind_profile, gen_idx, data_idx, CT_TGEN, PMAX); 
        if flag_600_gen
            gen_info = Wrapper.config_data.matpower_most_data.('solar_profile_info');
        end
        gen_idx = gen_info.data_map.gen;
        data_idx = gen_info.data_map.columns;
        if flag_600_gen
            VRE_solar_profile = create_dam_profile(Wrapper.forecast.solar_profile, gen_idx, data_idx, CT_TGEN, PMAX); 
        end
        %% Adding Load Profiles from forecast %%
        load_info = Wrapper.config_data.matpower_most_data.('load_profile_info');
        load_idx = load_info.data_map.bus;
        data_idx = load_info.data_map.columns;
        % load_profile = dam_load_profile(Wrapper.forecast.load_profile, load_idx, data_idx);
        
        for i = 1 : length(Wrapper.config_data.day_ahead_market.cosimulation_bus)
            cosim_bus_number = Wrapper.config_data.day_ahead_market.cosimulation_bus(i,1);
            idx_cosim_bus = find(load_idx == cosim_bus_number); 
            load_idx(idx_cosim_bus) = [];
            data_idx(idx_cosim_bus) = [];
        end
        Load_MW_profile= create_dam_profile(Wrapper.forecast.load_profile*0.5, load_idx, data_idx, CT_TBUS, PD); 
        MVAR_MW_ratio = Wrapper.mpc.bus(:,QD)./ Wrapper.mpc.bus(:,PD);
        Load_MVAR_profile = create_dam_profile(Wrapper.forecast.load_profile, load_idx, data_idx, CT_TBUS, QD, MVAR_MW_ratio); 
        
        profiles = [];
        profiles = getprofiles(VRE_wind_profile, profiles); 
        if flag_600_gen
            profiles = getprofiles(VRE_solar_profile, profiles);
        end
        profiles = getprofiles(Load_MW_profile, profiles);
        profiles = getprofiles(Load_MVAR_profile, profiles);
        
        %% Getting DAM bids from Co-simulation %%
        if Wrapper.config_data.include_helics
                Wrapper = Wrapper.get_DAM_bids_from_helics();
        else
                Wrapper = Wrapper.get_DAM_bids_from_wrapper(time_granted, flex_profile_DAM, price_range, bid_blocks);
        end
        

        %% Extracting Raw System model for modifications %%
%         mpc_mod = struct();
%         mpc_mod.bus = Wrapper.mpc.bus;
%         mpc_mod.gen = Wrapper.mpc.gen;
%         mpc_mod.gencost = Wrapper.mpc.gencost;
%         mpc_mod.branch = Wrapper.mpc.branch;
%         mpc_mod.baseMVA = Wrapper.mpc.baseMVA;
%         mpc_mod.genfuel = Wrapper.mpc.genfuel;
%         mpc_mod.reserves = Wrapper.mpc.reserves;
%         mpc_mod.zones = Wrapper.mpc.zones;

        
        mpc_mod = Wrapper.mpc;
        %%%%%%%%%%%%%%%%%%%%%%% Adding storage %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        if storage_option
            if Wrapper.config_data.include_helics
                % storage_specs = read_json("storage_config.json");
                % pause(1);
                Wrapper = get_storage_from_helics(Wrapper);
                storage_specs = Wrapper.storage_specs;
            else
                storage_specs = read_json("storage_config.json");
            end
            %Detect and remove existing storage
            if stor.state == 1
                %Remove from .gen
                mpc_mod.gen(st_data.UnitIdx,:) = [];
                %Remove from .gencost
                mpc_mod.gencost(st_data.UnitIdx,:) = [];
                %Remove from .genfuel
                mpc_mod.genfuel(st_data.UnitIdx,:) = [];
                stor.state = 0;
            end
            %Add new storage
            [~,mpc_mod,~,st_data] = addstorage(storage_custom(storage_specs),mpc_mod);
            stor = storage_custom(storage_specs);
            stor.gen = mpc_mod.gen(st_data.UnitIdx,:);
            stor.gencost = mpc_mod.gencost(st_data.UnitIdx,:);
            stor.genfuel = mpc_mod.genfuel(st_data.UnitIdx,:);
            stor.state = 1;
        end
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
             
        %% Adding Dispatchable Load Profiles from Bids %%
        for i = 1 : length(Wrapper.config_data.day_ahead_market.cosimulation_bus)
            bus_number = Wrapper.config_data.day_ahead_market.cosimulation_bus(i,1);
            DSO_DAM_bid = Wrapper.DAM_bids{bus_number}; 
            
            DSO_DAM_Bid_Coeff = zeros(24,3);
            for t = 1:24
                Actual_cost = zeros(length(DSO_DAM_bid.Q_bid(t,:)),1);
                for k = 1:size(DSO_DAM_bid.Q_bid, 2)
                   if k == 1
                       Actual_cost(k) = 0 + (DSO_DAM_bid.Q_bid(t,k) - 0)*DSO_DAM_bid.P_bid(t,k) ;
                   else
                       Actual_cost(k) = Actual_cost(k-1) + (DSO_DAM_bid.Q_bid(t,k) - DSO_DAM_bid.Q_bid(t,k-1))*DSO_DAM_bid.P_bid(t,k) ;
                   end
                end 
                DSO_DAM_Bid_Coeff(t,1:3) = polyfit(-1*transpose(DSO_DAM_bid.Q_bid(t,:)), -1*Actual_cost, 2);
                DSO_DAM_RES_MAX= -1*max(DSO_DAM_bid.Q_bid, [], 2);
            end
            % DAM_Bid_Coeff{bus_number} = DSO_DAM_bid_Coeff;
            % DAM_RES_MAX{bus_number} = DSO_DAM_RES_MAX;
           
            Generator_index = size(mpc_mod.gen,1) + 1;
            
            %%% Adding the Dispatchable Load as a new Generator %%%
            mpc_mod.genfuel(Generator_index, :) = {{'Dispatchable Load'; bus_number}}; 
            mpc_mod.gen(Generator_index,:) = 0;   %new entry of 0's
            mpc_mod.gen(Generator_index,1) = bus_number;   %set bus to 1 *Hardcoded*
            mpc_mod.gen(Generator_index,4) = 0;% Maximum reactive power output .gen(,4)
            mpc_mod.gen(Generator_index,5) = 0;% Minimum reactive power output .gen(,5)
            mpc_mod.gen(Generator_index,6) = 1;   %Voltage 1 p.u.
            mpc_mod.gen(Generator_index,8) = 1;   %gen status on
            mpc_mod.gen(Generator_index,10) = -10000; %min generation - Initialize with Large Number
            mpc_mod.gencost(Generator_index,1) = 2;   %Polynomial model
            mpc_mod.gencost(Generator_index,4) = 3;   %Degree 3 polynomial

            %%% Adding the profiles for Dispatchable Load %%%
            
            DSO_DAM_UNRES_MW_profile = create_dam_profile(DSO_DAM_bid.constant_MW, bus_number, 1, CT_TBUS, PD);
            profiles = getprofiles(DSO_DAM_UNRES_MW_profile, profiles);

            DSO_DAM_UNRES_MVAR_profile = create_dam_profile(DSO_DAM_bid.constant_MVAR, bus_number, 1, CT_TBUS, QD);
            profiles = getprofiles(DSO_DAM_UNRES_MVAR_profile, profiles);
           
            DSO_RES_MW_profile = create_dam_profile(DSO_DAM_RES_MAX, Generator_index, 1, CT_TGEN, PMIN);
            profiles = getprofiles(DSO_RES_MW_profile, profiles);
            
            DSO_RES_C0_profile = create_dam_profile(DSO_DAM_Bid_Coeff(:,1), Generator_index, 1, CT_TGENCOST, 5);
            DSO_RES_C1_profile = create_dam_profile(DSO_DAM_Bid_Coeff(:,2), Generator_index, 1, CT_TGENCOST, 6);
            DSO_RES_C2_profile = create_dam_profile(DSO_DAM_Bid_Coeff(:,3), Generator_index, 1, CT_TGENCOST, 7);
            profiles = getprofiles(DSO_RES_C0_profile, profiles);
            profiles = getprofiles(DSO_RES_C1_profile, profiles);
            profiles = getprofiles(DSO_RES_C2_profile, profiles);
            
        end

        
%         %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%         mpc = Wrapper.mpc;

        %%%%%%%%%%%%%% Add constant fields here %%%%%%%%%%%%%%%%%%%%%%%
%         mpc.genfuel(add_gen_index,:) = mpc.genfuel(1,:); %Copy genfuel from 1
%         mpc.gen(add_gen_index,:) = 0;   %new entry of 0's
%         mpc.gen(add_gen_index,1) = 1;   %set bus to 1 *Hardcoded*
%         mpc.gen(add_gen_index,4) = flexibility * abs(Wrapper.mpc.bus(1,4));% Maximum reactive power output .gen(,4)
%         mpc.gen(add_gen_index,5) = -1 * flexibility * abs(Wrapper.mpc.bus(1,4));% Minimum reactive power output .gen(,5)
%         mpc.gen(add_gen_index,6) = 1;   %Voltage 1 p.u.
%         mpc.gen(add_gen_index,8) = 1;   %gen status on
%         mpc.gen(add_gen_index,10) = -10000; %min generation
%         mpc.gencost(add_gen_index,1) = 2;   %Polynomial model
%         mpc.gencost(add_gen_index,4) = 3;   %Degree 3 polynomial
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%         mpc.gen(:, 18) = mpc.gen(:, 17)*10;
%         mpc.gen(:, 19) = mpc.gen(:, 17)*10;
%         mpc.gen(:, 7) =mpc.gen(:, 7)*10;

        %% Adding Ramping Constraints for Generators  %%
        if flag_600_gen == 1
            mpc_mod.gen(:, 17) = mpc_mod.gen(:, 19)*1;
            mpc_mod.gen(:, 18) = mpc_mod.gen(:, 19)*1;
            mpc_mod.gen(:, 20) = mpc_mod.gen(:, 19)*1;
        else
            temp = mpc_mod.gen(:,17)*60;
            % mpc_mod.gen(:, 17) = temp;
            mpc_mod.gen(:, 18) = temp;
            mpc_mod.gen(:, 19) = temp;
            mpc_mod.gen(:, 20) = temp;
            mpc_mod.gen(77:end, 18:20) = 10000;
        end

        % mpc_mod.branch(:,6:8) = mpc_mod.branch(:,6:8)*0.5;
        % mpc_mod.branch(7,6:8) = mpc_mod.branch(7,6:8)*3;

        infgen_idx = find( mpc_mod.gen(:,9) <  mpc_mod.gen(:,10));
        mpc_mod.gen(infgen_idx,9) = 0;
        

        xgd_table.colnames = { 'CommitKey' };
        xgd_table.data = 1*ones(size(mpc_mod.gen, 1),1);
        xgd = loadxgendata(xgd_table, mpc_mod);
        must_run_idx = Wrapper.mustrun_genId; %% Nuclear + VRE
        if flag_18_gen
            must_run_idx = [10:18]; %% for Test case      
        end
        xgd_table.data(must_run_idx) = 2;
        xgd = loadxgendata(xgd_table, mpc_mod);
        if flag_600_gen == 1
            xgd.PositiveLoadFollowReserveQuantity(1:end) = mpc_mod.gen(:, 19)*1; 
        else
            xgd.PositiveLoadFollowReserveQuantity = mpc_mod.gen(:,17)*60; %mpc_mod.gen(:,19)*2;
            xgd.PositiveLoadFollowReserveQuantity(77:end) = 10000; %% temporarily Hard coded for VRE generation
        end 
        xgd.NegativeLoadFollowReserveQuantity = xgd.PositiveLoadFollowReserveQuantity;

        if time_granted == 0
            xgd.InitialPg = mpc_mod.gen(:, 10);
            xgd.InitialState = 1*ones(size(mpc_mod.gen, 1),1);
        else
%             xgd.InitialPg = Wrapper.results.RTM.PG(end, 2:end)';
            xgd.InitialPg = Wrapper.results.DAM.PG(end, 2:end)';
%             for i = 1 : length(Wrapper.config_data.day_ahead_market.cosimulation_bus)
%                 generator_index = size(mpc_mod.gen,1) - (i-1);
%                 dis_load_idx = size(mpc_mod.gen,1)-(i-1);
%                 xgd.InitialPg(generator_index) = 0;
%             end
            %% Generalize later %
        end
        %% Adding Ramping Constraints for dispatchable loads  %%
%         for i = length(Wrapper.config_data.day_ahead_market.cosimulation_bus):-1:1
%             dis_load_idx = size(mpc_mod.gen,1)-(i-1);
%             xgd.CommitKey(dis_load_idx) = 2;
%             xgd.PositiveLoadFollowReserveQuantity(dis_load_idx) = 20000;
%             xgd.NegativeLoadFollowReserveQuantity(dis_load_idx) = 20000;
%         end
        for i = 1 : length(Wrapper.config_data.day_ahead_market.cosimulation_bus)
            dis_load_idx = size(mpc_mod.gen,1)-(i-1);
            xgd.CommitKey(dis_load_idx) = 2;
            xgd.PositiveLoadFollowReserveQuantity(dis_load_idx) = 20000;
            xgd.NegativeLoadFollowReserveQuantity(dis_load_idx) = 20000;
        end

        %% Solving DAM %%
        nt = size(profiles(1).values, 1);
        if storage_option
            mdi = loadmd(mpc_mod, nt, xgd, st_data, [], profiles);
        else
            mdi = loadmd(mpc_mod, nt, xgd, [], [], profiles);
        end
        
        for t = 1:nt
            mdi.FixedReserves(t,1,1) = mpc_mod.reserves;
        end
        
        fprintf('Wrapper: Running DA Market at Time %s\n', (datestr(datenum(Wrapper.config_data.start_time) + (time_granted/86400))))
        mpopt = mpoption('verbose', 1, 'out.all', 1, 'most.dc_model', 1, 'opf.dc.solver','GUROBI');
        if flag_18_gen
            mpopt = mpoption('verbose', 3, 'out.all', 2, 'most.dc_model', 1, 'opf.dc.solver','DEFAULT');
        end
        % mpopt = mpoption('verbose', 1, 'out.all', 1, 'most.dc_model', 1);
%         mpopt.mips.max_it = 2000;
        mpopt = mpoption(mpopt, 'most.uc.run', flag_uc);
        mdo = most(mdi, mpopt);
        
        %% Storing DAM Results %%
        if mdo.results.success == 1
            ms        = most_summary(mdo);
            curr_day  = floor(time_granted/86400);
            DAM_start = curr_day* 86400 + 3600; % results for first hour
            DAM_end   = curr_day* 86400 + 86400; % results for last hour
            DAM_time  = linspace(DAM_start, DAM_end, 24)'; 
            if isempty(Wrapper.results.DAM)
                   Wrapper.results.DAM.PG  = [DAM_time ms.Pg'];
                   Wrapper.results.DAM.PD  = [DAM_time ms.Pd'];
                   Wrapper.results.DAM.LMP = [DAM_time ms.lamP'];
                   Wrapper.results.DAM.UC  = [DAM_time ms.u'];
               else
                   Wrapper.results.DAM.PG  = [Wrapper.results.DAM.PG;  DAM_time ms.Pg'];
                   Wrapper.results.DAM.PD  = [Wrapper.results.DAM.PD;  DAM_time ms.Pd'];
                   Wrapper.results.DAM.LMP = [Wrapper.results.DAM.LMP; DAM_time ms.lamP'];
                   Wrapper.results.DAM.UC  = [Wrapper.results.DAM.UC;  DAM_time ms.u'];
            end

        else
            fprintf('Wrapper: DAM OPF Failed on attempt');
        end

        for i = 1 : length(Wrapper.config_data.day_ahead_market.cosimulation_bus)

			   Bus_number = Wrapper.config_data.day_ahead_market.cosimulation_bus(length(Wrapper.config_data.day_ahead_market.cosimulation_bus)-i+1,1);
               Generator_index = size(mpc_mod.gen,1);
               Wrapper.DAM_allocations{Bus_number}.P_clear =  ms.lamP(Bus_number,:); 
               Wrapper.DAM_allocations{Bus_number}.Q_clear =  ms.Pg(Bus_number,:);

               mpc_mod.genfuel(Generator_index,:) = [];
               mpc_mod.gen(Generator_index,:) = [];
               mpc_mod.gencost(Generator_index,:) = [];
	       end
        % save('-text', 'msout.txt', 'ms');
        %%%%%%%%%%%%% Remove extra generator %%%%%%%%%%%%%%%%
%         mpc.genfuel(add_gen_index,:) = [];
%         mpc.gen(add_gen_index,:) = [];
%         mpc.gencost(add_gen_index,:) = [];
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        if DAM_plot_option
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
            Wrapper = Wrapper.update_VRE_from_profiles(time_granted,   'wind_profile_info',  'wind_profile');
            if flag_600_gen
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

sec=toc()
min=sec/60