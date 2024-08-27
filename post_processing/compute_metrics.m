clc
clear all



addpath ('../src/')
wrapper_startup;
Wrapper = MATPOWERWrapper('../src/wrapper_config_v2.json', 0);


storage_specs = read_json("storage_config.json");


fid = fopen('../src/wrapper_config_v2.json'); 
raw = fread(fid,inf); 
str = char(raw'); 
fclose(fid); 
case_data = jsondecode(str);

start_time = datetime(case_data.start_time);
end_time = datetime(case_data.end_time);

% Cases = {'storage_v1'};
Cases = {'storage_v2'};
% case_data.include_storage  = false;


casename = Cases(1);
case_file_RT_LMP = strcat('../outputs/',char(casename),'_RTM_LMP.csv');
case_data_RT_LMP = readmatrix(case_file_RT_LMP);
case_file_RT_PG = strcat('../outputs/',char(casename),'_RTM_PG.csv');
case_data_RT_PG= readmatrix(case_file_RT_PG);
case_file_RT_PD = strcat('../outputs/',char(casename),'_RTM_PD.csv');
case_data_RT_PD = readmatrix(case_file_RT_PD);

case_file_LMP_DAM = strcat('../outputs/',char(casename),'_DAM_LMP.csv');
case_data_LMP_DAM_raw = readmatrix(case_file_LMP_DAM);
case_file_PG_DAM = strcat('../outputs/',char(casename),'_DAM_PG.csv');
case_data_PG_DAM_raw = readmatrix(case_file_PG_DAM);
case_file_PD_DAM = strcat('../outputs/',char(casename),'_DAM_PD.csv');
case_data_PD_DAM_raw = readmatrix(case_file_PD_DAM);

for i=1:length(case_data_RT_LMP(:,1))
    time_RT(i, 1) = start_time + (case_data_RT_LMP(i,1)/86400);
end


if case_data.include_storage 
    case_file_DAM_P_storage = strcat('../outputs/',char(casename),'_DAM_P_storage.csv');
    case_data_DAM_P_storage = readmatrix(case_file_DAM_P_storage);
    case_file_RTM_P_storage = strcat('../outputs/',char(casename),'_RTM_P_storage.csv');
    case_data_RTM_P_storage = readmatrix(case_file_RTM_P_storage);


    storage_DAM_P_bus = zeros(length(case_data_PD_DAM_raw),9);
    storage_DAM_P_bus(:,1) = case_data_PD_DAM_raw(:,1);
    storage_RTM_P_bus  = zeros(length(case_data_RT_PD), 9);
    storage_RTM_P_bus(:,1) = storage_RTM_P_bus(:,1);
    storage_names = fieldnames (storage_specs);
    for i = 1:length(storage_names)
        storage_name = storage_names{i};
        bus = storage_specs.(storage_name).bus;
        storage_DAM_P_bus(:, bus+1)  = storage_DAM_P_bus(:, bus+1) +  case_data_DAM_P_storage(:,i+1);
        storage_RTM_P_bus(:, bus+1)  = storage_RTM_P_bus(:, bus+1) +  case_data_RTM_P_storage(:,i+1);
    end
end

    

for bus_idx = 2:9
    if case_data.include_storage 
        DA_cost(:, bus_idx) = case_data_LMP_DAM_raw(:,bus_idx).* (case_data_PD_DAM_raw(:,bus_idx) - storage_DAM_P_bus(:,bus_idx));
    else
        DA_cost(:, bus_idx) = case_data_LMP_DAM_raw(:,bus_idx).* case_data_PD_DAM_raw(:,bus_idx);
    end
end

for t_idx = 1:length(time_RT)
    time_seconds = case_data_RT_LMP(t_idx, 1);
    hour_idx = floor((time_seconds)/3600) + 1;
    DA_PD = case_data_PD_DAM_raw(hour_idx, 2:9);
    if case_data.include_storage 
       RT_PD = case_data_RT_PD(t_idx, 2:9) -  storage_RTM_P_bus(t_idx, 2:9);
    else
       RT_PD = case_data_RT_PD(t_idx, 2:9);
    end
    DA_RT_Diff = RT_PD - DA_PD;
    RT_cost(t_idx, :) = DA_RT_Diff.*case_data_RT_LMP(t_idx, 2:9)*Wrapper.config_data.real_time_market.interval/3600;
end


total_DA_Market_cost = sum(sum(DA_cost),2);
total_RT_Market_cost = sum(sum(RT_cost),2);
total_cost = (total_DA_Market_cost + total_RT_Market_cost);
total_cost_M = round(total_cost/1e6,3);
fprintf('Total Cost of Operation for DAM is %f, \n',total_DA_Market_cost);
fprintf('Total Cost of Operation for RTM is %f, \n',total_RT_Market_cost);
fprintf('Total Cost of Operation for ERCOT is %fM$, \n',total_cost_M);

if case_data.include_storage
    net_loads = case_data_RT_PD(:, 2:9) - storage_RTM_P_bus(:, 2:9);
    peak_load =  max(sum(net_loads, 2))/1e3;
else
    net_loads = case_data_RT_PD(:, 2:9);
    peak_load =  max(sum(net_loads, 2))/1e3;
end
fprintf('Peak Load is %fGW, \n',peak_load);


ston_C02_NG_CC = 0.57;
ston_C02_NG_SC = 0.78;
ston_C02_Coal = 1.21;

NG_CC_idx = []; NG_SC_idx = []; Coal_idx = [];
for k = 1:length(Wrapper.mpc.genfuel)
    if Wrapper.mpc.genfuel{k, 1} == "coal"
        Coal_idx = [Coal_idx; k];
    end
    if Wrapper.mpc.genfuel{k, 1} == "ng"
        if Wrapper.mpc.gencost(k, 6) < 30
            NG_CC_idx = [NG_CC_idx; k];
        else
            NG_SC_idx = [NG_SC_idx; k];
        end
    end    
end


Coal_gen_MWH =  sum(sum(case_data_RT_PG(:, Coal_idx' +1), 2))*Wrapper.config_data.real_time_market.interval/3600;
NG_CC_gen_MWH = sum(sum(case_data_RT_PG(:, NG_CC_idx' +1), 2))*Wrapper.config_data.real_time_market.interval/3600;
NG_SC_gen_MWH = sum(sum(case_data_RT_PG(:, NG_SC_idx' +1), 2))*Wrapper.config_data.real_time_market.interval/3600;

total_Sh = NG_CC_gen_MWH*ston_C02_Coal + NG_CC_gen_MWH*ston_C02_NG_CC + NG_SC_gen_MWH*ston_C02_NG_SC;
fprintf('Total ShortTons of Co2 is %fST, \n',total_Sh);

total_energy_MWH  =  sum(sum(net_loads))*Wrapper.config_data.real_time_market.interval/3600;
average_energy_cost = total_cost/total_energy_MWH;
fprintf('Average Cost of Energy is %f$/MWH, \n',average_energy_cost);

% average_DA_lmp = mean(mean(case_file_LMP_DAM(:, 2:9)));
% average_marginal_cost = 
% fprintf('Peak DA LMP is %f$/MWH, \n',average_DA_lmp);
% fprintf('Average RT LMP is %f$/MWH, \n',average_RT_lmp);
