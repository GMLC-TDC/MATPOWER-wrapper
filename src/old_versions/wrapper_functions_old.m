function functions = wrapper_functions
    functions.read_config=@read_config;
    functions.write_config=@write_config;
    functions.prepare_helics_config=@prepare_helics_config;
    functions.create_profiles=@create_profiles;
    functions.interpolate_profile_to_powerflow_interval=@interpolate_profile_to_powerflow_interval;
end
  

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%% Create HELICS Configuration %%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function config_data = prepare_helics_config(config_file_name, config_data)
  
    config_data.helics_config.coreInit = "--federates=1";
    config_data.helics_config.coreName = "Transmission Federate";
    config_data.helics_config.publications = [];
    config_data.helics_config.subscriptions = [];

    for i = 1:length(config_data.cosimulation_bus)
        cosim_bus = config_data.cosimulation_bus(i);
        %%%%%%%%%%%%%%%%% Creating Pubs & Subs for physics_powerflow %%%%%%%%%%%%%%%%%
        if config_data.include_physics_powerflow
            publication.key =   strcat (config_data.helics_config.name, '/bus', mat2str(cosim_bus), '_voltage' );
            publication.type =   "complex";
            publication.global =   true;
            config_data.helics_config.publications = [config_data.helics_config.publications publication];

            subscription.key =   strcat (config_data.helics_config.name, '/bus', mat2str(cosim_bus), '_load' );
            subscription.type =   "complex";
            subscription.required =   true;
            config_data.helics_config.subscriptions = [config_data.helics_config.subscriptions subscription];
        end
        %%%%%%%%%%%%%%%%% Creating Pubs & Subs for real time market %%%%%%%%%%%%%%%%%%    
        if config_data.include_real_time_market
            publication.key =   strcat (config_data.helics_config.name, '/bus', mat2str(cosim_bus), '_RT_PQ_cleared' );
            publication.type =   "vector";
            publication.global =   true;
            config_data.helics_config.publications = [config_data.helics_config.publications publication];  

            subscription.key =   strcat (config_data.helics_config.name, '/bus', mat2str(cosim_bus), '_RT_PQ_bids' );
            subscription.type =   "vector";
            subscription.required =   true;
            config_data.helics_config.subscriptions = [config_data.helics_config.subscriptions subscription];
        end
        %%%%%%%%%%%%%%%%% Creating Pubs & Subs for day ahead market %%%%%%%%%%%%%%%%%% 
        if config_data.include_day_ahead_market
            publication.key =   strcat (config_data.helics_config.name, '/bus', mat2str(cosim_bus), '_DA_PQ_cleared' );
            publication.type =   "complex";
            publication.global =   true;
            config_data.helics_config.publications = [config_data.helics_config.publications publication];

            subscription.key =   strcat (config_data.helics_config.name, '/bus', mat2str(cosim_bus), '_DA_PQ_bids' );
            subscription.type =   "complex";
            subscription.required =   true;
            config_data.helics_config.subscriptions = [config_data.helics_config.subscriptions subscription];
        end
    end  
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%% Create Load Profiles from Input data %%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function profiles = create_profiles(input_file_name, profile_info, start_time, end_time, required_resolution, duration)
  
    input_resolution = profile_info.resolution;
    input_data_reference_time = datenum(profile_info.starting_time, 'yyyy-mm-dd HH:MM:SS');
    %{ 
    Calculating Start & End points to load only the profile data required for Simulation.
    This will help reduce the memory by not having to store the data worth of a year.  
    %}
    start_data_point = (start_time - input_data_reference_time)*3600*24/input_resolution;
    end_data_point   = (end_time - input_data_reference_time)*3600*24 /input_resolution;
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
%         logger.debug('Loading Load profiles for bus %s from input column', bus_idx, data_idx);
        [profiles(:,data_idx), profile_intervals] = interpolate_profile_to_powerflow_interval(data(:,data_idx), input_resolution, required_resolution, duration);
    end
    profiles(:,1) = profile_intervals;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%% Interpolate Input Profile  %%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
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
function val = read_config(file)
    fid = fopen(file); 
    raw = fread(fid,inf); 
    str = char(raw'); 
    fclose(fid); 
    val = jsondecode(str);
end
  
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%% Write Json Configuration %%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function write_config(file, data)
    str = jsonencode (data);
    fid = fopen(file, 'w'); 
    fwrite(fid, str);
    fclose(fid); 
end