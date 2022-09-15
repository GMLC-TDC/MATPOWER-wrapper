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
    helics; 
    Wrapper = Wrapper.prepare_helics_config('helics_config.json', 'DSOSim'); 
    fprintf('Wrapper: Helics version = %s\n', helicsGetVersion)
    fed = helicsCreateCombinationFederateFromConfig('helics_config.json');
    
    pubkeys_count = helicsFederateGetPublicationCount(fed);
    pub_keys = cell(pubkeys_count, 1);
    for pub_idx = 1:pubkeys_count
        pub_object = helicsFederateGetPublicationByIndex(fed, pub_idx-1);
        pub_keys(pub_idx) = cellstr(helicsPublicationGetName(pub_object));
    end
    
    subkeys_count = helicsFederateGetInputCount(fed);
    sub_keys = cell(subkeys_count, 1);
    for sub_idx = 1:subkeys_count
        sub_object = helicsFederateGetInputByIndex(fed, sub_idx-1);
        sub_keys(sub_idx) = cellstr(helicsSubscriptionGetTarget(sub_object));
    end
    helicsFederateEnterExecutingMode(fed);
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
        time_granted  = helicsFederateRequestTime(fed, next_helics_time)
        fprintf('Wrapper: Reqeuested  %d and Granted %d\n', next_helics_time, time_granted)
    else
        time_granted = next_helics_time
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
            
            % Get data from HELICS
            time_request = time_granted+1;
            while time_granted < time_request
                time_granted  = helicsFederateRequestTime(fed, next_helics_time);
            end
              
            for bus_idx= 1 : length(Wrapper.config_data.cosimulation_bus)
                cosim_bus = Wrapper.config_data.cosimulation_bus(bus_idx)
                temp = strfind(sub_keys, strcat('.pcc.', mat2str(cosim_bus), '.pq'));
                subkey_idx = find(~cellfun(@isempty,temp));
                sub_object = helicsFederateGetSubscription(fed, sub_keys(subkey_idx));
                demand = helicsInputGetComplex(sub_object);
                Wrapper.mpc.bus(cosim_bus, 3) = real(demand);
                Wrapper.mpc.bus(cosim_bus, 4) = imag(demand);
                fprintf('Wrapper: Got Load %d+%d from CoSIM bus %d\n', real(demand), imag(demand), cosim_bus)
            end
            
            
            % Collect measurements from distribution networks
            Wrapper = Wrapper.run_power_flow(time_granted);  
          
            for bus_idx= 1 : length(Wrapper.config_data.cosimulation_bus)
                cosim_bus = Wrapper.config_data.cosimulation_bus(bus_idx);
                cosim_bus_voltage = Wrapper.mpc.bus(cosim_bus, 8) * Wrapper.mpc.bus(cosim_bus, 10);
                cosim_bus_angle = Wrapper.mpc.bus(cosim_bus, 9)*pi/180;
                voltage = pol2cart(cosim_bus_angle, cosim_bus_voltage);
                
                temp = strfind(pub_keys, strcat('.pcc.', mat2str(cosim_bus), '.pnv')) ;
                pubkey_idx = find(~cellfun(@isempty,temp));
                pub_object = helicsFederateGetPublication(fed, pub_keys(pubkey_idx));
                helicsPublicationPublishComplex(pub_object, complex(voltage(1), voltage(2)));
            end
            
            tnext_physics_powerflow = tnext_physics_powerflow + Wrapper.config_data.physics_powerflow.interval;
    end
    
    if time_granted == Wrapper.duration     %end infinite loop
        time_granted = Wrapper.duration+1;
    end

end

helicsFederateDisconnect(fed);
    