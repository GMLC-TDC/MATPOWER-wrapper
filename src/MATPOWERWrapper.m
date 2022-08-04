classdef MATPOWERWrapper
    
   properties
      config_data
      start_time
      end_time
      duration
      MATPOWERModifier
      mpc
      profiles = struct();
      results =  struct('PF', 1,'RTM', {},'DAM', {});

   end
   
   methods
       %% Intializing the Wrapper %% 
       function obj = MATPOWERWrapper(config_file)
           obj.config_data = read_json(config_file);
           obj.start_time  = datenum(obj.config_data.start_time, 'yyyy-mm-dd HH:MM:SS');
           obj.end_time    = datenum(obj.config_data.end_time, 'yyyy-mm-dd HH:MM:SS');
           obj.duration = (obj.end_time - obj.start_time)*24*3600;
           case_name = strcat(obj.config_data.matpower_most_data.datapath, obj.config_data.matpower_most_data.case_name);
           obj.MATPOWERModifier = MATPOWERModifier(case_name);
           obj.mpc = obj.MATPOWERModifier.MATPOWERModel;
           
           obj.results(1).PF =  struct('VM',{});
           obj.results(1).RTM =  struct('PG',{} , 'PD', {}, 'LMP', {});
       end
       
       function obj = read_profiles(obj, input_fieldname, output_fieldname)
           
           profile_info = obj.config_data.matpower_most_data.(input_fieldname);
           data_path = obj.config_data.matpower_most_data.datapath; 
           input_file_name = strcat(data_path, profile_info.filename);  
           input_resolution = profile_info.resolution;
           input_data_reference_time = datenum(profile_info.starting_time, 'yyyy-mm-dd HH:MM:SS');
           required_resolution = obj.config_data.physics_powerflow.interval;

           %{ 
           Calculating Start & End points to load only the profile data required for Simulation.
           This will help reduce the memory by not having to store the data worth of a year.  
           %}
           start_data_point = (obj.start_time - input_data_reference_time)*3600*24/input_resolution;
           end_data_point   = (obj.end_time - input_data_reference_time)*3600*24 /input_resolution;
           start_column = min(profile_info.data_map.columns)-1;
           end_column = max(profile_info.data_map.columns)-1;
           %{ 
            Loadind data based on the simulation duration.  
            Assumption:
                The profiles are provided in csv.
                The simulation duration is a subset of the duration of the data.  
                If else, The user is expected to adjust the start/end dates or the profile. 
           %}
           data  = dlmread(input_file_name, ',', [start_data_point+1, 0, end_data_point+1, end_column]);    
           for idx = 1: length(profile_info.data_map.columns)
               data_idx = profile_info.data_map.columns(idx);
    %                 logger.debug('Loading Load profiles for bus %s from input column', bus_idx, data_idx);
               [profiles(:,data_idx), profile_intervals] = interpolate_profile_to_powerflow_interval(data(:,data_idx), input_resolution, required_resolution, obj.duration);
           end
           profiles(:,1) = profile_intervals;
           obj.profiles.(output_fieldname) = profiles;
       end 
       
       function obj = prepare_helics_config(obj, config_file_name)
           obj.config_data.helics_config.coreInit = "--federates=1";
           obj.config_data.helics_config.coreName = "Transmission Federate";
           obj.config_data.helics_config.publications = [];
           obj.config_data.helics_config.subscriptions = [];

            for i = 1:length(obj.config_data.cosimulation_bus)
                cosim_bus = obj.config_data.cosimulation_bus(i);
                %%%%%%%%%%%%%%%%% Creating Pubs & Subs for physics_powerflow %%%%%%%%%%%%%%%%%
                if obj.config_data.include_physics_powerflow
                    publication.key =   strcat (obj.config_data.helics_config.name, '/bus', mat2str(cosim_bus), '_voltage' );
                    publication.type =   "complex";
                    publication.global =   true;
                    obj.config_data.helics_config.publications = [obj.config_data.helics_config.publications publication];

                    subscription.key =   strcat (obj.config_data.helics_config.name, '/bus', mat2str(cosim_bus), '_load' );
                    subscription.type =   "complex";
                    subscription.required =   true;
                    obj.config_data.helics_config.subscriptions = [obj.config_data.helics_config.subscriptions subscription];
                end
                %%%%%%%%%%%%%%%%% Creating Pubs & Subs for real time market %%%%%%%%%%%%%%%%%%    
                if obj.config_data.include_real_time_market
                    publication.key =   strcat (obj.config_data.helics_config.name, '/bus', mat2str(cosim_bus), '_RT_PQ_cleared' );
                    publication.type =   "vector";
                    publication.global =   true;
                    obj.config_data.helics_config.publications = [obj.config_data.helics_config.publications publication];  

                    subscription.key =   strcat (obj.config_data.helics_config.name, '/bus', mat2str(cosim_bus), '_RT_PQ_bids' );
                    subscription.type =   "vector";
                    subscription.required =   true;
                    obj.config_data.helics_config.subscriptions = [obj.config_data.helics_config.subscriptions subscription];
                end
                %%%%%%%%%%%%%%%%% Creating Pubs & Subs for day ahead market %%%%%%%%%%%%%%%%%% 
                if obj.config_data.include_day_ahead_market
                    publication.key =   strcat (obj.config_data.helics_config.name, '/bus', mat2str(cosim_bus), '_DA_PQ_cleared' );
                    publication.type =   "complex";
                    publication.global =   true;
                    obj.config_data.helics_config.publications = [obj.config_data.helics_config.publications publication];

                    subscription.key =   strcat (obj.config_data.helics_config.name, '/bus', mat2str(cosim_bus), '_DA_PQ_bids' );
                    subscription.type =   "complex";
                    subscription.required =   true;
                    obj.config_data.helics_config.subscriptions = [obj.config_data.helics_config.subscriptions subscription];
                end
            end
            write_json(config_file_name, obj.config_data.helics_config);
       end
       
       function obj = update_loads_from_profiles(obj, time, profile_info_fieldname, profile_fieldname)
            
           profile = obj.profiles.(profile_fieldname);
           profile_row = find(time==profile(:,1));
           
           profile_info = obj.config_data.matpower_most_data.(profile_info_fieldname);
           profile_info_col_idx = profile_info.data_map.columns;
           profile_info_bus_idx = profile_info.data_map.bus;

           kW_kVAR_ratio = obj.mpc.bus(:,3)./ obj.mpc.bus(:,4);
           obj.mpc.bus(profile_info_bus_idx, 3) = profile(profile_row, profile_info_col_idx)';
           obj.mpc.bus(profile_info_bus_idx, 4) = obj.mpc.bus(profile_info_bus_idx, 3) ./ kW_kVAR_ratio; 
    
       end
       
       function obj = update_VRE_from_profiles(obj, time, profile_info_fieldname, profile_fieldname)
            
           profile = obj.profiles.(profile_fieldname);
           profile_row = find(time == profile(:,1));
           
           profile_info = obj.config_data.matpower_most_data.(profile_info_fieldname);
           profile_info_col_idx = profile_info.data_map.columns;
           profile_info_gen_idx = profile_info.data_map.gen;

           obj.mpc.gen(profile_info_gen_idx, 9) = profile(profile_row, profile_info_col_idx)';   
    
       end
       
       function obj = update_dispatch_from_cosim(obj, time, values)
           %% Placeholder
       end
       
       function obj = update_bids_from_cosim(obj, time, bids)
           %% Placeholder
       end
           
       function obj = run_power_flow(obj, time, mpoptPF)       
%            obj.mpc.bus(:,12) = 1.3* ones(length(obj.mpc.bus(:,12)),1);
%            obj.mpc.bus(:,13) = 0.7* ones(length(obj.mpc.bus(:,13)),1);
           solution = runpf(obj.mpc, mpoptPF);                 
           if isempty(obj.results.PF)
               obj.results.PF(1).VM = [time solution.bus(:, 8)'];
           else
               obj.results.PF.VM = [obj.results.PF.VM; time solution.bus(:, 8)'];
           end       
       end
       
       function obj = run_RT_market(obj, time, mpoptOPF)       
           solution = rundcopf(obj.mpc, mpoptOPF); 
           if solution.success == 1
               if isempty(obj.results.RTM)
                   obj.results.RTM(1).PG  = [time solution.gen(:, 2)'];
                   obj.results.RTM(1).PD  = [time solution.bus(:, 3)'];
                   obj.results.RTM(1).LMP = [time solution.bus(:, 14)'];
               else
                   obj.results.RTM.PG  = [obj.results.RTM.PG;  time solution.gen(:, 2)'];
                   obj.results.RTM.PD  = [obj.results.RTM.PD;  time solution.bus(:, 3)'];
                   obj.results.RTM.LMP = [obj.results.RTM.LMP; time solution.bus(:, 14)'];
               end  
           else
               obj.results.RTM.PG  = [obj.results.RTM.PG;  time solution.gen(:, 2)'];
               obj.results.RTM.PD  = [obj.results.RTM.PD;  time solution.bus(:, 3)'];
               obj.results.RTM.LMP = [obj.results.RTM.LMP; time solution.bus(:, 14)'];
               
           end
               
       end
       
   end
       
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%% Interpolate Input Profile  %%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Utility Functions %%
function [required_profile, required_intervals] = interpolate_profile_to_powerflow_interval(input_data, input_data_resolution, required_resolution, duration)
  
            raw_data_duration  = (length(input_data)-1)*input_data_resolution;
            raw_data_intervals = linspace(0, raw_data_duration, (raw_data_duration/input_data_resolution)+1)';
            required_intervals = linspace(0, duration, (duration/required_resolution)+1)';
            if raw_data_intervals(1) <= required_intervals(1) && raw_data_intervals(end) >= required_intervals(end)
                interpolated_data = interp1 (raw_data_intervals, input_data, required_intervals, "spline");
                %%    required_profile = [required_intervals interpolated_data];
                required_profile = interpolated_data;
                logger.debug('Interpolating input profile for simulation intervals');  
            else
                logger.warn('Simulation intervals is out of interpolation range for the input profile');  
                %%    required_profile = [raw_data_intervals input_data];
                required_profile = input_data;
            end
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%% Read Json Configuration %%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function val = read_json(file)
           fid = fopen(file); 
           raw = fread(fid,inf); 
           str = char(raw'); 
           fclose(fid); 
           val = jsondecode(str);
end 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%% Write Json Configuration %%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function write_json(file, data)
    str = jsonencode (data);
    fid = fopen(file, 'w'); 
    fwrite(fid, str);
    fclose(fid); 
end