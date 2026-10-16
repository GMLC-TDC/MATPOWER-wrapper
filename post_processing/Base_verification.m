clc
clear all
close all

fid = fopen('../src/wrapper_config_v2.json'); 
raw = fread(fid,inf); 
str = char(raw'); 
fclose(fid); 
case_data = jsondecode(str);
start_time = datetime(case_data.start_time);

casename='BASE';

case_file_EV = strcat('C:/Users/jacob/Documents/MatpowerWrapper/EVtest/EV_model/output_',char(casename),'.csv');
case_data_EV(:,:) = readmatrix(case_file_EV);

casename = 'BASEU';
case_file_EV = strcat('C:/Users/jacob/Documents/MatpowerWrapper/EVtest/EV_model/output_',char(casename),'.csv');
case_data_EVU(:,:) = readmatrix(case_file_EV);

time = case_data_EV(:,1);
time = datetime((time/86400)+start_time);

EV_list = {'R4_12_47_1_meter_2_ev', 'R4_12_47_1_meter_4_ev', 'R4_12_47_1_meter_5_ev', 'R4_12_47_1_meter_6_ev', 'R4_12_47_1_meter_11_ev', 'R4_12_47_1_meter_12_ev', 'R4_12_47_1_meter_16_ev', 'R4_12_47_1_meter_18_ev', 'R4_12_47_1_meter_19_ev', 'R4_12_47_1_meter_20_ev', 'R4_12_47_1_meter_28_ev', 'R4_12_47_1_meter_31_ev', 'R4_12_47_1_meter_34_ev', 'R4_12_47_1_meter_39_ev', 'R4_12_47_1_meter_43_ev', 'R4_12_47_1_meter_47_ev', 'R4_12_47_1_meter_48_ev', 'R4_12_47_1_meter_49_ev', 'R4_12_47_1_meter_52_ev', 'R4_12_47_1_meter_58_ev', 'R4_12_47_1_meter_64_ev'};

GLD_file = "C:/Users/jacob/Documents/MatpowerWrapper/EVtest/EV_model/distribution_simulation/EV_charger_outputR4_12_47_1.csv";
% GLD_EV_data_raw = readmatrix(GLD_file, 'NumHeaderLines', 8);
GLD_EV_data_raw = readtable(GLD_file, 'NumHeaderLines', 8);
GLD_EV_data_select = removevars(GLD_EV_data_raw, EV_list);

TT = table2timetable(GLD_EV_data_select, 'RowTimes', 'x_Timestamp');
TT = sortrows(TT);
% must be sorted by time 
TT_hourly = retime(TT, 'hourly', 'mean'); % linear interpolation onto an hourly grid % Convert back to a regular table if you want
GLD_EV_data_select_hourly = timetable2table(TT_hourly);

vars = setdiff(GLD_EV_data_select_hourly.Properties.VariableNames, {'x_Timestamp'}, 'stable');
GLD_EV_data = 1000*sum(GLD_EV_data_select_hourly{120:264, vars}, 2);
% GLD_EV_data_alt = 1000*sum(GLD_EV_data_select(1:1729,2:end),2);
% GLD_time = 0:300:518400;
% GLD_time = datetime((GLD_time/86400)+start_time);

plot(time,case_data_EV(:,4))
hold on
% plot(time,case_data_EVU(:,4))
plot(GLD_EV_data_select_hourly.x_Timestamp(120:264),GLD_EV_data)
grid on
ylabel("EV Load (W)")
xlabel("Time")
legend(["Sim, unoptimized","GLD"])
hold off

