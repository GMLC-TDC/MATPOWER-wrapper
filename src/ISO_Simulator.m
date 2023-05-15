clc
clear all
clear classes
warning('off','MATLAB:polyfit:RepeatedPointsOrRescale');

case_name = 'Poly10';


%% Check if MATLAB or OCTAVE
isOctave = exist('OCTAVE_VERSION', 'builtin') ~= 0;
%% Load Model
wrapper_startup;
Wrapper = MATPOWERWrapper('wrapper_config.json', isOctave);

%% Read profile and save it within a strcuture called load
src_dir = prev_dir();
Wrapper = Wrapper.read_profiles('load_profile_info', 'load_profile');
Wrapper = Wrapper.read_profiles('wind_profile_info', 'wind_profile');
cd(src_dir);

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
tnext_day_ahead_market = 0;

time_granted = 0;
next_helics_time =  min([tnext_physics_powerflow, tnext_real_time_market, tnext_day_ahead_market]);

%% Updating the FLow Limits %%
Wrapper.MATPOWERModifier = Wrapper.MATPOWERModifier.modify_line_limits([1:8], 0.5);
Wrapper.MATPOWERModifier = Wrapper.MATPOWERModifier.modify_line_limits(7, 3);
Wrapper =  Wrapper.update_model(); % Do this to get the new limits into the the mpc structure

%% Adding Zonal Reserves %%
res_zones = Wrapper.mpc.bus(:, 11);
max_zonal_loads =  [19826.18, 25282.32, 19747.12, 6694.77]; % Based on 2016 data
% Assuming reserve requirement to be 2 % of peak load
zonal_res_req = max_zonal_loads'*2.5/100; 
% assuming Non VRE generators to participate in reserve allocations
reserve_genId = [1:33];
% assuming 5% reserve availiability from all generators
reserve_genQ = Wrapper.mpc.gen(reserve_genId, 9)* 7.5/100; 
% assuming constant price for reserves from all generators
reserve_genP = 1*ones(length(reserve_genId), 1);
Wrapper.MATPOWERModifier = Wrapper.MATPOWERModifier.add_zonal_reserves(reserve_genId, reserve_genQ, reserve_genP, zonal_res_req);
Wrapper =  Wrapper.update_model(); % Do this to get reserves into the the mpc structure

%% Default Bid Configurations for Wrapper if HELICS is not Used. %%
bid_blocks = 10;
price_range = [10, 50];
flex_max = 20; % Defines maximum flexibility as a % of total load
if ~isOctave
  flex_profile = unifrnd(0,flex_max,[24,1])/100;
endif
flex_profile = flex_max*ones(24, 1)/100;

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

        tnext_physics_powerflow = tnext_physics_powerflow + Wrapper.config_data.physics_powerflow.interval;
    end
    
    %% *************************************************************
    %% Running Day Ahead Energy Arbitrage Market
    %% ************************************************************* 
    
    if (time_granted >= tnext_day_ahead_market) && (Wrapper.config_data.include_day_ahead_market) && (time_granted < Wrapper.duration)
%         fprintf('Wrapper: Current Time %s\n', (datetime(736543,'ConvertFrom','datenum') + seconds(time_granted)))
%         fprintf('Wrapper: DA forecast at Time %s\n', (datetime(Wrapper.config_data.start_time) + seconds(time_granted)))
        fprintf('Wrapper: DA forecast at Time %s\n', datestr(datenum(Wrapper.config_data.start_time) + (time_granted/86400)))
        Wrapper = Wrapper.get_DA_forecast('wind_profile', time_granted, Wrapper.config_data.day_ahead_market.interval);
        Wrapper = Wrapper.get_DA_forecast('load_profile', time_granted, Wrapper.config_data.day_ahead_market.interval);
        
        %% Adding Generation Profiles from forecast for VRE-based Generators %%
        gen_info = Wrapper.config_data.matpower_most_data.('wind_profile_info');
        gen_idx = gen_info.data_map.gen;
        data_idx = gen_info.data_map.columns;
        % gen_profile = dam_gen_profiles(Wrapper.forecast.wind_profile, gen_idx, data_idx); 
        VRE_profile = create_dam_profile(Wrapper.forecast.wind_profile, gen_idx, data_idx, CT_TGEN, PMAX); 
    
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
        Load_MW_profile= create_dam_profile(Wrapper.forecast.load_profile, load_idx, data_idx, CT_TBUS, PD); 
        MVAR_MW_ratio = Wrapper.mpc.bus(:,QD)./ Wrapper.mpc.bus(:,PD);
        Load_MVAR_profile = create_dam_profile(Wrapper.forecast.load_profile, load_idx, data_idx, CT_TBUS, QD, MVAR_MW_ratio); 

        
        profiles = getprofiles(VRE_profile); 
        profiles = getprofiles(Load_MW_profile, profiles);
        profiles = getprofiles(Load_MVAR_profile, profiles);
        
        %% Getting DAM bids from Co-simulation %%
        if Wrapper.config_data.include_helics
                Wrapper = Wrapper.get_DAM_bids_from_helics();
        else
                Wrapper = Wrapper.get_DAM_bids_from_wrapper(time_granted, flex_profile, price_range, bid_blocks);
        end
        
        %%%%%%%%%%%%%%% Add new profiles here %%%%%%%%%%%%%%%%%%%%%%%%%
%         add_gen_index = size(Wrapper.mpc.gencost,1)+1;
        %%% Unresponsive %%%
        % Constant component of real load .bus(,3)
%         add_profile = create_dam_profile( (ones(size(flex_profile,1),1) - (flex_profile)) .* (load_MW_profile.values(:,1,1)), 1, 1, 1, 3);
%         profiles = getprofiles(add_profile, profiles);
        % Constant component of reactive load .bus(,4)
        %%% Responsive %%%
        
        % Minimum real power output .gen(,10)
%         add_profile = create_dam_profile((flex_profile) .* (-1 * flexibility * (load_struct.values(:,1,1))), add_gen_index, 1, 2, 10);
%         profiles = getprofiles(add_profile, profiles);
        % Polynomial coefficients .gen(,5-7)
        
%           profiles = getprofiles(gen_struct); 
%         profiles = getprofiles(load_struct, profiles);

        %% Extracting Raw System model for modifications %%
        mpc_mod = Wrapper.mpc;
             
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
           
            Generator_index = size(Wrapper.mpc.gen,1) + 1;
            
            %%% Adding the Dispatchable Load as a new Generator %%%
            mpc_mod.genfuel(Generator_index, :) = {{'Dispatchable Load'; bus_number}}; 
            mpc_mod.gen(Generator_index,:) = 0;   %new entry of 0's
            mpc_mod.gen(Generator_index,1) = bus_number;   %set bus to 1 *Hardcoded*
            mpc_mod.gen(Generator_index,4) = 0;% Maximum reactive power output .gen(,4)
            mpc_mod.gen(Generator_index,5) = 0;% Minimum reactive power output .gen(,5)
            mpc_mod.gen(Generator_index,6) = 1;   %Voltage 1 p.u.
            mpc_mod.gen(Generator_index,8) = 1;   %gen status on
            mpc_mod.gen(Generator_index,10) = -10000; %min generation - Large Number
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

        
%         add_profile = create_dam_profile(Coeff(:,1), add_gen_index, 1, 9, 5);
%         profiles = getprofiles(add_profile, profiles);
%         add_profile = create_dam_profile(Coeff(:,2), add_gen_index, 1, 9, 6);
%         profiles = getprofiles(add_profile, profiles);
%         add_profile = create_dam_profile(Coeff(:,3), add_gen_index, 1, 9, 7);
%         profiles = getprofiles(add_profile, profiles);
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
        mpc_mod.gen(:, 18) = mpc_mod.gen(:,17)*60;
        mpc_mod.gen(:, 19) = mpc_mod.gen(:,17)*60;
        mpc_mod.gen(77:end, 18:20) = 10000;
        % mpc_mod.branch(:,6:8) = mpc_mod.branch(:,6:8)*0.5;
        % mpc_mod.branch(7,6:8) = mpc_mod.branch(7,6:8)*3;
        % mpc_mod = rundcopf(mpc_mod);
        xgd_table.colnames = { 'CommitKey' };
        xgd_table.data = 1*ones(size(mpc_mod.gen, 1),1);
        must_run_idx = [75:110]; %% Nuclear + VRE
        xgd_table.data(must_run_idx) = 2;
        xgd = loadxgendata(xgd_table, mpc_mod);
        xgd.PositiveLoadFollowReserveQuantity =  mpc_mod.gen(:,17)*60;
        xgd.PositiveLoadFollowReserveQuantity(77:end) = 10000; %% temporarily Hard coded for VRE generators
        xgd.NegativeLoadFollowReserveQuantity = xgd.PositiveLoadFollowReserveQuantity;
        if time_granted == 0
            xgd.InitialState = 1*ones(size(mpc_mod.gen, 1),1);
%         else:
%             xgd.InitialPg = Wrapper.PG.;
        end
        %% Adding Ramping Constraints for dispatchable loads  %%
        for i = length(Wrapper.config_data.day_ahead_market.cosimulation_bus):-1:1
            dis_load_idx = size(mpc_mod.gen,1)-(i-1);
            xgd.CommitKey(dis_load_idx) = 2;
            xgd.PositiveLoadFollowReserveQuantity(dis_load_idx) = 20000;
            xgd.NegativeLoadFollowReserveQuantity(dis_load_idx) = 20000;
        end

        %% Solving DAM %%
        nt = size(profiles(1).values, 1);
        mdi = loadmd(mpc_mod, nt, xgd, [], [], profiles);
        
        for t = 1:nt
            mdi.FixedReserves(t,1,1) = mpc_mod.reserves;
        end
        
        fprintf('Wrapper: Running DA Market at Time %s\n', (datestr(datenum(Wrapper.config_data.start_time) + (time_granted/86400))))
        % mpopt = mpoption('verbose', 1, 'out.all', 1, 'most.dc_model', 0, 'opf.dc.solver','GLPK');
        mpopt = mpoption('verbose', 1, 'out.all', 0, 'most.dc_model', 1);
        mpopt.mips.max_it = 200;
        mpopt = mpoption(mpopt, 'most.uc.run', 0);
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
        % save('-text', 'msout.txt', 'ms');
        %%%%%%%%%%%%% Remove extra generator %%%%%%%%%%%%%%%%
%         mpc.genfuel(add_gen_index,:) = [];
%         mpc.gen(add_gen_index,:) = [];
%         mpc.gencost(add_gen_index,:) = [];
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
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
        fprintf('Wrapper: NEXT DAM at Time %s\n', (tnext_day_ahead_market))
    end
    
    
    %% *************************************************************
    %% Running Real Time Energy Imbalance Market
    %% *************************************************************    
    if (time_granted >= tnext_real_time_market) && (Wrapper.config_data.include_real_time_market) && (time_granted < Wrapper.duration)
            time_granted;
            Wrapper = Wrapper.update_loads_from_profiles(time_granted, 'load_profile_info', 'load_profile');
            Wrapper = Wrapper.update_VRE_from_profiles(time_granted, 'wind_profile_info', 'wind_profile');
            
            if isOctave
              hod = floor(24 * (datenum(current_time) - floor(datenum(current_time)))) + 1;
            else
              hod = hour(current_time)+1;
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
            
            tnext_real_time_market = tnext_real_time_market + Wrapper.config_data.real_time_market.interval;
    end
end

Wrapper.write_results(case_name)

if Wrapper.config_data.include_helics 
    helicsFederateDestroy(Wrapper.helics_data.fed)
    helics.helicsCloseLibrary()
end