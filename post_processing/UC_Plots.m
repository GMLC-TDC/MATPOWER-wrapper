clc
clear all
close all

% Cases = {'Base','Flex10','Flex20','Mis10','Mis20'};
Cases = {'UCBase', 'UCStor', 'UCFlex10', 'UCFlex20', 'UCMis10', 'UCMis20'};
fid = fopen('../src/wrapper_config_v2.json'); 
raw = fread(fid,inf); 
str = char(raw'); 
fclose(fid); 
case_data = jsondecode(str);
start_time = datetime(case_data.start_time);

case_data_PG_DAM_raw=zeros(5,168,608);
case_data_PD_DAM_raw=zeros(5,168,9);

for i=1:length(Cases)
    casename = Cases(i);

    case_file_LMP = strcat('../outputs/',char(casename),'_RTM_LMP.csv');
    case_data_LMP(i,:,:) = readmatrix(case_file_LMP);
    case_file_PG = strcat('../outputs/',char(casename),'_RTM_PG.csv');
    case_data_PG(i,:,:) = readmatrix(case_file_PG);
    case_file_PD = strcat('../outputs/',char(casename),'_RTM_PD.csv');
    case_data_PD(i,:,:) = readmatrix(case_file_PD);
    
    if i==1
        case_file_LMP_DAM = strcat('../outputs/',char(casename),'_DAM_LMP.csv');
        case_data_LMP_DAM_raw(i,:,:) = readmatrix(case_file_LMP_DAM);
        case_file_PG_DAM = strcat('../outputs/',char(casename),'_DAM_PG.csv');
        case_data_PG_DAM_raw(i,:,1:end-1) = readmatrix(case_file_PG_DAM);
        case_file_PD_DAM = strcat('../outputs/',char(casename),'_DAM_PD.csv');
        case_data_PD_DAM_raw(i,:,:) = readmatrix(case_file_PD_DAM);
    else
        case_file_LMP_DAM = strcat('../outputs/',char(casename),'_DAM_LMP.csv');
        case_data_LMP_DAM_raw(i,:,:) = readmatrix(case_file_LMP_DAM);
        case_file_PG_DAM = strcat('../outputs/',char(casename),'_DAM_PG.csv');
        case_data_PG_DAM_raw(i,:,:) = readmatrix(case_file_PG_DAM);
        case_file_PD_DAM = strcat('../outputs/',char(casename),'_DAM_PD.csv');
        case_data_PD_DAM_raw(i,:,:) = readmatrix(case_file_PD_DAM);
    end
end

time = case_data_LMP(1,:,1);
time = datetime((time/86400)+start_time);