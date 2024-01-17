clc 
clear all
old_mpc = read_json('ERCOT_8_system_v2.json');
load("ERCOT\8_bus_600_gen_case_v2.mat");
new_mpc = old_mpc;
new_mpc.gencost = mpc.gencost;

write_json('ERCOT\ERCOT_8_system_v3.json',new_mpc);



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