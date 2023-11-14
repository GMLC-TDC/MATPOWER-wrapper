classdef MATPOWERModifier
    
   properties
       MATPOWERModel 
   end
   
   methods
       %%  Read Model from JSON or m format %%
       function obj = MATPOWERModifier(config_file)
           obj.MATPOWERModel = obj.read_model(config_file);
           %% Any Nan Values in Ramping are converted to InF %%
           gen_idx = isnan(obj.MATPOWERModel.gen(:,19));
           obj.MATPOWERModel.gen(gen_idx, 19) = 10000;
       end
       
       %% Change the Branch Flow Limits 
       function obj = modify_line_limits(obj, line_idx, scale)
           obj.MATPOWERModel.branch(line_idx,6:8) = obj.MATPOWERModel.branch(line_idx,6:8)*scale; 
       end
       
       %% Adding Zonal Reserves
       function obj = add_zonal_reserves(obj, reserve_gen_idx, reserve_gen_Q, reserve_gen_P, reserve_Req)
                      
           zones = unique(obj.MATPOWERModel.bus(:, 11));
           obj.MATPOWERModel.reserves = struct();
           
           obj.MATPOWERModel.reserves.zones = zeros(length(zones), size(obj.MATPOWERModel.gen, 1));
           for gen_idx = 1:size(obj.MATPOWERModel.gen, 1)
               bus_idx = obj.MATPOWERModel.gen(gen_idx, 1);
               gen_zone = obj.MATPOWERModel.bus(bus_idx, 11);
               obj.MATPOWERModel.reserves.zones(gen_zone, gen_idx) = 1;
           end
           
           obj.MATPOWERModel.reserves.qty = zeros(size(obj.MATPOWERModel.gen, 1), 1);
           obj.MATPOWERModel.reserves.qty(reserve_gen_idx, 1) = reserve_gen_Q;
           
           obj.MATPOWERModel.reserves.cost = zeros(size(obj.MATPOWERModel.gen, 1), 1);
           obj.MATPOWERModel.reserves.cost(reserve_gen_idx, 1) = reserve_gen_P;
           
           obj.MATPOWERModel.reserves.req(zones, 1) = reserve_Req;
           
       end
       
       function model = read_model(obj, case_name)
           if isempty(regexp (case_name,'.json'))
               model = loadcase(case_name); %% Load in built MATPOWER CASE
           else
               fid = fopen(case_name);
               raw = fread(fid,inf); 
               str = char(raw'); 
               fclose(fid); 
               model = jsondecode(str);
           end
       end
       
       %%  Wrtie MATPOWER Model to JSON format%%
       function write_model(obj, file)
           str = jsonencode (obj.mpc);
           fid = fopen(file, 'w'); 
           fwrite(fid, str);
           fclose(fid); 
       end 
      
   end
   
end