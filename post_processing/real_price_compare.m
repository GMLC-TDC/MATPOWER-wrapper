clc
clear all
close all

Cases = {'Base','Flex10','Flex20','Mis10','Mis20'};
fid = fopen('../src/wrapper_config_v2.json'); 
raw = fread(fid,inf); 
str = char(raw'); 
fclose(fid); 
case_data = jsondecode(str);
start_time = datetime(case_data.start_time);
start_day = 5;

for i=1:length(Cases)
    casename = Cases(i);
    case_file_LMP = strcat('../outputs/',char(casename),'_RTM_LMP.csv');
    case_data_LMP(i,:,:) = readmatrix(case_file_LMP);
    case_file_PG = strcat('../outputs/',char(casename),'_RTM_PG.csv');
    case_data_PG(i,:,:) = readmatrix(case_file_PG);
    case_file_PD = strcat('../outputs/',char(casename),'_RTM_PD.csv');
    case_data_PD(i,:,:) = readmatrix(case_file_PD);

    case_file_LMP_DAM = strcat('../outputs/',char(casename),'_DAM_LMP.csv');
    case_data_LMP_DAM_raw(i,:,:) = readmatrix(case_file_LMP_DAM);
    case_file_PG_DAM = strcat('../outputs/',char(casename),'_DAM_PG.csv');
    case_data_PG_DAM_raw(i,:,:) = readmatrix(case_file_PG_DAM);
    case_file_PD_DAM = strcat('../outputs/',char(casename),'_DAM_PD.csv');
    case_data_PD_DAM_raw(i,:,:) = readmatrix(case_file_PD_DAM);
end

real_prices_file_DA = strcat('../system_data/','2021_ERCOT_DA_prices_Aug.csv');
real_prices_file_RT = strcat('../system_data/','2021_ERCOT_RT_prices_Aug.csv');
real_prices_data_DA = readmatrix(real_prices_file_DA);
real_prices_data_RT = readmatrix(real_prices_file_RT);

start_index = 96*(start_day-1) - 4;
for i=start_index:start_index+(96*5)
    max_real_LMP(i-start_index+1) = max(transpose(real_prices_data_RT(i,2:16)));
    min_real_LMP(i-start_index+1) = min(transpose(real_prices_data_RT(i,2:16)));
end




