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
flexibility = 0.25;      %Defines maximum flexibility as a % of total load
flex_profile = [1;1;1;1;0.5;0.5;0.5;0.5;1;1;1;1;0;0;0;0;1;1;1;1;0;0;0;0]; % Percentage of flexibility allowed for each hour increment (1 = max flex)
flex_profile = ones(24,1);
blocks = 10;

%% ISO Simulator Starts here
while time_granted < Wrapper.duration

%     next_helics_time =  min([tnext_physics_powerflow, tnext_real_time_market, tnext_day_ahead_market]);
    next_helics_time =  min([tnext_day_ahead_market]);

    if Wrapper.config_data.include_helics
        time_granted  = helicsFederateRequestTime(Wrapper.helics_data.fed, next_helics_time);
%         fprintf('Wrapper: Requested  %ds in time and got Granted %d\n', next_helics_time, time_granted)
%         fprintf('Wrapper: Current Time %s\n', (datetime(736543,'ConvertFrom','datenum') + seconds(time_granted)))
        fprintf('Wrapper: Current Time %s\n', (datetime(Wrapper.config_data.start_time) + seconds(time_granted)))
    else
        time_granted = next_helics_time;
%         fprintf('Wrapper: Current Time %s\n', string(datetime(736543,'ConvertFrom','datenum') + seconds(time_granted)))
        fprintf('Wrapper: Current Time %s\n', (datetime(Wrapper.config_data.start_time) + seconds(time_granted)))
    end
    
    if (time_granted >= tnext_real_time_market) && (Wrapper.config_data.include_real_time_market)
            time_granted;
            Wrapper = Wrapper.update_loads_from_profiles(time_granted, 'load_profile_info', 'load_profile');
            Wrapper = Wrapper.update_VRE_from_profiles(time_granted, 'wind_profile_info', 'wind_profile');
            
            % Collect Bids from DSO
            if Wrapper.config_data.include_helics
                Wrapper = Wrapper.get_bids_from_helics();
            else
                Wrapper = Wrapper.get_bids_from_wrapper(time_granted, flexibility, price_range, blocks);
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
    
    
    if (time_granted >= tnext_day_ahead_market) && (Wrapper.config_data.include_day_ahead_market) && (max(Wrapper.profiles.wind_profile(:,1)) >= (time_granted + Wrapper.config_data.day_ahead_market.interval))
%         fprintf('Wrapper: Current Time %s\n', (datetime(736543,'ConvertFrom','datenum') + seconds(time_granted)))
        fprintf('Wrapper: Current Time %s\n', (datetime(Wrapper.config_data.start_time) + seconds(time_granted)))
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
        %%%%%%%%%%%%%%% Add new profiles here %%%%%%%%%%%%%%%%%%%%%%%%%
        add_gen_index = size(Wrapper.mpc.gencost,1)+1;
        %%% Unresponsive %%%
        % Constant component of real load .bus(,3)
        add_profile = generic_profile( (ones(size(flex_profile,1),1) - (flexibility * flex_profile)) .* (load_struct.values(:,1,1)), 1, 1, 1, 3);
        profiles = getprofiles(add_profile, profiles);
        % Constant component of reactive load .bus(,4)
        %%% Responsive %%%
        
        % Minimum real power output .gen(,10)
        add_profile = generic_profile((flex_profile) .* (-1 * flexibility * (load_struct.values(:,1,1))), add_gen_index, 1, 2, 10);
        profiles = getprofiles(add_profile, profiles);
        % Polynomial coefficients .gen(,5-7)
        Coeff = zeros(24,3);
        for t = 1:24
            Q_bid = linspace(0, flex_profile(t) * flexibility*load_struct.values(t,1,1), blocks);
            P_bid = linspace(max(price_range), min(price_range),blocks);
            Actual_cost = zeros(length(Q_bid),1);
            for k = 1:length(Q_bid)
                if k == 1
                    Actual_cost(k) = 0 + (Q_bid(k) - 0)*P_bid(k) ;
                else
                    Actual_cost(k) = Actual_cost(k-1) + (Q_bid(k) - Q_bid(k-1))*P_bid(k) ;
                end
            end  
            Coeff(t,1:3) = polyfit(-1*Q_bid, -1*Actual_cost, 2);
        end

        add_profile = generic_profile(Coeff(:,1), add_gen_index, 1, 9, 5);
        profiles = getprofiles(add_profile, profiles);
        add_profile = generic_profile(Coeff(:,2), add_gen_index, 1, 9, 6);
        profiles = getprofiles(add_profile, profiles);
        add_profile = generic_profile(Coeff(:,3), add_gen_index, 1, 9, 7);
        profiles = getprofiles(add_profile, profiles);
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        mpc = Wrapper.mpc;

        %%%%%%%%%%%%%% Add constant fields here %%%%%%%%%%%%%%%%%%%%%%%
        mpc.genfuel(add_gen_index,:) = mpc.genfuel(1,:); %Copy genfuel from 1
        mpc.gen(add_gen_index,:) = 0;   %new entry of 0's
        mpc.gen(add_gen_index,1) = 1;   %set bus to 1 *Hardcoded*
%         mpc.gen(add_gen_index,4) = flexibility * abs(Wrapper.mpc.bus(1,4));% Maximum reactive power output .gen(,4)
        mpc.gen(add_gen_index,5) = -1 * flexibility * abs(Wrapper.mpc.bus(1,4));% Minimum reactive power output .gen(,5)
        mpc.gen(add_gen_index,6) = 1;   %Voltage 1 p.u.
        mpc.gen(add_gen_index,8) = 1;   %gen status on
        mpc.gen(add_gen_index,10) = -10000; %min generation
        mpc.gencost(add_gen_index,1) = 2;   %Polynomial model
        mpc.gencost(add_gen_index,4) = 3;   %Degree 3 polynomial
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        mpc.gen(:, 17:20) = Inf;
        mpc.branch(:,6:8) = mpc.branch(:,6:8)*1.25;
        nt = size(profiles(1).values, 1);
        mdi = loadmd(mpc, nt, [], [], [], profiles);
        
        define_constants;
        mpopt = mpoption('verbose', 1, 'out.all', 1, 'most.dc_model', 0, 'opf.dc.solver','GLPK');
%         mpopt = mpoption('verbose', 1, 'out.all', 0, 'most.dc_model', 1);
        mdo = most(mdi, mpopt);
        ms = most_summary(mdo);
        % save('-text', 'msout.txt', 'ms');
        %%%%%%%%%%%%% Remove extra generator %%%%%%%%%%%%%%%%
        mpc.genfuel(add_gen_index,:) = [];
        mpc.gen(add_gen_index,:) = [];
        mpc.gencost(add_gen_index,:) = [];
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