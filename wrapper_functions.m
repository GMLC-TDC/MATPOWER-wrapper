function functions = wrapper_functions
  functions.read_config=@read_config;
  functions.write_config=@write_config;
  functions.prepare_helics_config=@prepare_helics_config;
  functions.interpolate_profile_to_powerflow_interval=@interpolate_profile_to_powerflow_interval;
end
  

  %%%%%%%%%%%%%%%% Create HEICS Configuration %%%%%%%%%%%%%%%%%
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

%%%%%%%%%%%%%%%%%%%%%%%%%% Interpolate Input Profile  %%%%%%%%%%%%%%%%%%%%%%%%%%
function required_profile = interpolate_profile_to_powerflow_interval(input_data, input_data_resolution, required_resolution, duration)
  
  raw_data_duration = length(input_data)*input_data_resolution;
  raw_data_intervals  = linspace(0, raw_data_duration, (raw_data_duration/input_data_resolution)+1)'(1:end-1);
  required__intervals  = linspace(0, duration, (duration/required_resolution)+1)'(1:end-1);
  
  if raw_data_intervals(1) <= required__intervals(1) && raw_data_intervals(end) >= required__intervals(end)
    interpolated_data = interp1 (raw_data_intervals, input_data, required__intervals, "spline");
    required_profile = [required__intervals interpolated_data];
    logger.warn('Interpolating input profile for simulation intervals');  
  else
    logger.warn('Simulation intervals is out of interpolation range for the input profile');  
    required_profile = [raw_data_intervals input_data];
  end
  
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%% Read Json Configuration %%%%%%%%%%%%%%%%%%%%%%%%%%
function val = read_config(file)
   fid = fopen(file); 
   raw = fread(fid,inf); 
   str = char(raw'); 
   fclose(fid); 
   val = jsondecode(str);
end

  
%%%%%%%%%%%%%%%%%%%%%%%%%% Write Json Configuration %%%%%%%%%%%%%%%%%%%%%%%%%%
function write_config(file, data)
       str = jsonencode (data, 'PrettyPrint', true);
       fid = fopen(file, 'w'); 
       fputs(fid, str);
       fclose(fid); 
  end