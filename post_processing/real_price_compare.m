clc
clear all
close all

addpath ('../src/')
wrapper_startup;
Wrapper = MATPOWERWrapper('../src/wrapper_config_v2.json', 0);
Wrapper = Wrapper.read_profiles('load_profile_info', 'load_profile');
load_total = transpose(sum(transpose(Wrapper.profiles.load_profile(:,2:9))));


% Cases = {'Base','Flex10','Flex20','Mis10','Mis20'};
Cases = {'Base_new'};
fid = fopen('../src/wrapper_config_v2.json'); 
raw = fread(fid,inf); 
str = char(raw'); 
fclose(fid); 
case_data = jsondecode(str);
start_time = datetime(case_data.start_time);
end_time = datetime(case_data.end_time);
start_day = 5;


for i = 1:length(load_total)
    load_time(i) = start_time + (Wrapper.profiles.load_profile(i,1)/86400);
end

% for i=1:length(Cases)
%     casename = Cases(i);
%     case_file_LMP = strcat('../outputs/',char(casename),'_RTM_LMP.csv');
%     case_data_LMP(i,:,:) = readmatrix(case_file_LMP);
%     case_file_PG = strcat('../outputs/',char(casename),'_RTM_PG.csv');
%     case_data_PG(i,:,:) = readmatrix(case_file_PG);
%     case_file_PD = strcat('../outputs/',char(casename),'_RTM_PD.csv');
%     case_data_PD(i,:,:) = readmatrix(case_file_PD);
% 
%     case_file_LMP_DAM = strcat('../outputs/',char(casename),'_DAM_LMP.csv');
%     case_data_LMP_DAM_raw(i,:,:) = readmatrix(case_file_LMP_DAM);
%     case_file_PG_DAM = strcat('../outputs/',char(casename),'_DAM_PG.csv');
%     case_data_PG_DAM_raw(i,:,:) = readmatrix(case_file_PG_DAM);
%     case_file_PD_DAM = strcat('../outputs/',char(casename),'_DAM_PD.csv');
%     case_data_PD_DAM_raw(i,:,:) = readmatrix(case_file_PD_DAM);
% end


casename = Cases(1);
case_file_LMP = strcat('../outputs/',char(casename),'_RTM_LMP.csv');
case_data_LMP = readmatrix(case_file_LMP);
case_file_PG = strcat('../outputs/',char(casename),'_RTM_PG.csv');
case_data_PG= readmatrix(case_file_PG);
case_file_PD = strcat('../outputs/',char(casename),'_RTM_PD.csv');
case_data_PD = readmatrix(case_file_PD);

case_file_LMP_DAM = strcat('../outputs/',char(casename),'_DAM_LMP.csv');
case_data_LMP_DAM_raw = readmatrix(case_file_LMP_DAM);
case_file_PG_DAM = strcat('../outputs/',char(casename),'_DAM_PG.csv');
case_data_PG_DAM_raw = readmatrix(case_file_PG_DAM);
case_file_PD_DAM = strcat('../outputs/',char(casename),'_DAM_PD.csv');
case_data_PD_DAM_raw = readmatrix(case_file_PD_DAM);


real_prices_file_DA = strcat('../system_data/','2021_ERCOT_DA_prices_Aug.csv');
real_prices_file_RT = strcat('../system_data/','2021_ERCOT_RT_prices_Aug.csv');
real_prices_data_DA = readtable(real_prices_file_DA);
real_prices_data_RT = readtable(real_prices_file_RT);
real_prices_data_table_DA = readtable(real_prices_file_DA);
real_prices_data_table_RT = readtable(real_prices_file_RT);

UTC_adjust = 2.0;
idx_time_RT = (real_prices_data_table_RT.Time >= start_time+ hours(UTC_adjust)) & (real_prices_data_table_RT.Time < end_time+ hours(UTC_adjust));
idx_time_DA = (real_prices_data_table_DA.Time >= start_time+ hours(UTC_adjust)) & (real_prices_data_table_DA.Time < end_time+ hours(UTC_adjust));
% idx_load = transpose(find(start_time_load<=load_time & load_time<=end_time_load));


real_prices_data_DA_interval = real_prices_data_table_DA(idx_time_DA,:);
real_prices_data_RT_interval = real_prices_data_RT(idx_time_RT,:);

real_prices_max_DA = max(real_prices_data_DA_interval{:,2:end}');
real_prices_min_DA = min(real_prices_data_DA_interval{:,2:end}');
real_prices_max_RT = max(real_prices_data_RT_interval{:,2:end}');
real_prices_min_RT = min(real_prices_data_RT_interval{:,2:end}');

% start_index_RT = 96*(start_day-1) - 4;
% for i=start_index_RT:(start_index_RT+(96*7))-1
%     max_real_LMP_RT(i-start_index_RT+1) = max(real_prices_data_RT(i,2:16));
%     min_real_LMP_RT(i-start_index_RT+1) = min(real_prices_data_RT(i,2:16));
%     time_real_RT(i-start_index_RT+1) = start_time + ((i-start_index_RT)/96);
% end
% 
% start_index_DA = 24*(start_day-1);
% for i=start_index_DA:(start_index_DA + (24*7))-1
%     max_real_LMP_DA(i-start_index_DA+1) = max(real_prices_data_DA(i,2:16));
%     min_real_LMP_DA(i-start_index_DA+1) = min(real_prices_data_DA(i,2:16));
%     time_real_DA(i-start_index_DA+1) = start_time + ((i-start_index_DA)/24);
% end

for i=1:length(case_data_LMP(:,1))
    LMP_time_RT(i) = start_time + (case_data_LMP(i,1)/86400);
end
for i = 1:length(case_data_LMP_DAM_raw(:,1))
    LMP_time_DA(i) = start_time + (case_data_LMP_DAM_raw(i,1)/86400);
end

actual_time_RT = real_prices_data_RT_interval.Time - hours(UTC_adjust);
actual_time_DA = real_prices_data_DA_interval.Time - hours(UTC_adjust);

%% Plot Figures
figure()
subplot(2,1,1)
plot(actual_time_RT,real_prices_min_RT, 'LineWidth',1.25)
hold on
plot(actual_time_RT,real_prices_max_RT, 'LineWidth',1.25)
plot(LMP_time_RT,mean(case_data_LMP(:,2:9),2), 'k', 'LineWidth',1.5)
% plot(LMP_time_RT,mean(case_data_LMP(:,2:end),2), 'k', 'LineWidth',1.5)
legend({'Actual (minimum)','Actual (maximum)','Simulation (Average)'})
ylabel('LMP($/MWHr)')
title('Actual Versus Simulated LMPs: Real Time')
grid on
% ylim([0,80])
% yyaxis right
% plot(LMP_time_RT,sum(case_data_PD(:,2:end),2))
% title('Actual Versus Simulated LMPs: Day Ahead')
% hold off

subplot(2,1,2)
plot(actual_time_DA,real_prices_min_DA, 'LineWidth',1.25)
hold on
plot(actual_time_DA,real_prices_max_DA, 'LineWidth',1.25)
plot(LMP_time_DA, mean(case_data_LMP_DAM_raw(:,2:9),2), 'k','LineWidth',1.5)
% plot(LMP_time_DA, min(case_data_LMP_DAM_raw(:,2:end),2), 'k','LineWidth',1.0)
legend({'Actual (minimum)','Actual (maximum)','Simulation (Average)'})
ylabel('LMP($/MWHr)')
grid on
% ylim([0,80])
% yyaxis right
% plot(LMP_time_DA, sum(case_data_PD_DAM_raw(:,2:end),2))
title('Actual Versus Simulated LMPs: Day Ahead')
hold off

% figure()
% yyaxis left
% plot(time_real_RT,min_real_LMP_RT)
% hold on
% plot(time_real_RT,max_real_LMP_RT)
% plot(LMP_time_RT,case_data_LMP(1,:,3))
% ylabel('LMP($/MWHr)')
% title('Real Time')
% yyaxis right
% plot(load_time,load_total)
% legend({'min','max','Bus 2','load'})
% hold off

% figure()
% yyaxis left
% plot(time_real_DA,min_real_LMP_DA)
% hold on
% plot(time_real_DA,max_real_LMP_DA)
% plot(LMP_time_DA,case_data_LMP_DAM_raw(1,:,3))
% ylabel('LMP($/MWHr)')
% title('Day Ahead')
% yyaxis right
% plot(load_time,load_total)
% legend({'min','max','Bus 2','load'})
% hold off



