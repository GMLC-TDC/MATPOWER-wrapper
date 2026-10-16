clc
clear all
close all


Cases = {'BASE','TOU','P2D','DAM','DAM_DSO'};

fid = fopen('../src/wrapper_config_v2.json'); 
raw = fread(fid,inf); 
str = char(raw'); 
fclose(fid); 
case_data = jsondecode(str);
start_time = datetime(case_data.start_time);

case_data_PG_DAM_raw=zeros(6,144,608);
case_data_PD_DAM_raw=zeros(6,144,9);


for i=1:length(Cases)
    casename = Cases(i);

    case_file_LMP = strcat('../outputs/',char(casename),'_RTM_LMP.csv');
    case_data_LMP(i,:,:) = readmatrix(case_file_LMP);
    case_file_PG = strcat('../outputs/',char(casename),'_RTM_PG.csv');
    case_data_PG(i,:,:) = readmatrix(case_file_PG);
    case_file_PD = strcat('../outputs/',char(casename),'_RTM_PD.csv');
    case_data_PD(i,:,:) = readmatrix(case_file_PD);
    case_file_EV = strcat('C:/Users/jacob/Documents/MatpowerWrapper/EVtest/EV_model/output_',char(casename),'.csv');
    case_data_EV(i,:,:) = readmatrix(case_file_EV);
    

    case_file_LMP_DAM = strcat('../outputs/',char(casename),'_DAM_LMP.csv');
    case_data_LMP_DAM_raw(i,:,:) = readmatrix(case_file_LMP_DAM);
    case_file_PG_DAM = strcat('../outputs/',char(casename),'_DAM_PG.csv');
    case_data_PG_DAM_raw(i,:,:) = readmatrix(case_file_PG_DAM);
    case_file_PD_DAM = strcat('../outputs/',char(casename),'_DAM_PD.csv');
    case_data_PD_DAM_raw(i,:,:) = readmatrix(case_file_PD_DAM);

end

casename = 'P2D1';
i = i + 1;

case_file_LMP = strcat('../outputs/',char(casename),'_RTM_LMP.csv');
case_data_LMP(i,:,:) = readmatrix(case_file_LMP);
case_file_PG = strcat('../outputs/',char(casename),'_RTM_PG.csv');
case_data_PG(i,:,:) = readmatrix(case_file_PG);
case_file_PD = strcat('../outputs/',char(casename),'_RTM_PD.csv');
case_data_PD(i,:,:) = readmatrix(case_file_PD);
case_file_EV = strcat('C:/Users/jacob/Documents/MatpowerWrapper/EVtest/EV_model/output_',char(casename),'.csv');
case_data_EV(i,:,:) = readmatrix(case_file_EV);
case_file_LMP_DAM = strcat('../outputs/',char(casename),'_DAM_LMP.csv');
case_data_LMP_DAM_raw(i,:,:) = readmatrix(case_file_LMP_DAM);
case_file_PG_DAM = strcat('../outputs/',char(casename),'_DAM_PG.csv');
case_data_PG_DAM_raw(i,:,:) = readmatrix(case_file_PG_DAM);
case_file_PD_DAM = strcat('../outputs/',char(casename),'_DAM_PD.csv');
case_data_PD_DAM_raw(i,:,:) = readmatrix(case_file_PD_DAM);

time = case_data_LMP(1,:,1);
time = datetime((time/86400)+start_time);
time_hourly = case_data_EV(1,:,1);
time_hourly = datetime(time_hourly, 'ConvertFrom', 'epochtime', 'Epoch', '2021-08-06');
time_DAM = case_data_LMP_DAM_raw(1,:,1);
time_DAM = datetime((time_DAM/86400)+start_time);

% Add in load from negative generator
for run=1:6
    % case_data_PD(run,:,6) = case_data_PD(run,:,6) - case_data_PG(run,:,end);
    case_data_PD_DAM_raw(run,:,6) = case_data_PD_DAM_raw(run,:,6) - case_data_PG_DAM_raw(run,:,end);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%% LMPs %%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
for run = 1:5
    figure()
    
    for bus=2:9
        plot(time(96:end),case_data_LMP(run,96:end,bus))
        hold on
    end
    grid on
    
    legend({'1','2','3','4','5','6','7','8'},"Location","northwest")
    
    ylabel("LMP")
    xlabel("Time")
    title(char(Cases(run)))
    
    hold off
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%% Bus 5 Total Load %%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
figure()

for run=1:5
    plot(time(96:end),case_data_PD(run,96:end,6))
    hold on
end
grid on

legend(Cases,"Location","northwest")
ylabel("Load")
xlabel("Time")
title("Bus 5 Total Load")
hold off

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%% Bus 5 LMPs by case %%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
figure()

for run=1:5
    plot(time(96:end),case_data_LMP(run,96:end,6))
    hold on
end
grid on

legend(Cases,"Location","northwest")
ylabel("LMP")
xlabel("Time")
title("Bus 5 LMPs")
hold off

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%% Bus 5 LMPs DSO Compare %%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
figure()

for run=4:5
    plot(time(96:end),case_data_LMP(run,96:end,6))
    hold on
    plot(time_DAM(24:end),case_data_LMP_DAM_raw(run,24:end,6))
end
grid on

legend({'uncoordinated, RT','uncoordinated, DA','coordinated, RT','coordinated, DA'},"Location","northwest")
ylabel("LMP")
xlabel("Time")
title("Bus 5 LMPs, DSO Coordination Comparison")
hold off


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%% EV Consumption %%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
figure()

for run=1:5
    subplot(5,1,run)
    plot(time_hourly(25:end),case_data_EV(run,25:end,2))
    hold on
    plot(time_hourly(25:end),case_data_EV(run,25:end,3))
    plot(time_hourly(25:end),case_data_EV(run,25:end,4))
    grid on
    legend({'Planned','Adjusted','Actual'},"Location","northwest")
    name_y = strcat("EV Load",char(Cases(run)));
    ylabel(name_y)
    xlabel("Time")
    hold off
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%% Compute Metrics %%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
RT_market_interval = 900;
Cases = {'BASE','TOU','P2D','DAM','DAM_DSO','P2D1'};

for run = 1:6
    for bus_idx = 2:9
        DA_cost(:, bus_idx) = case_data_LMP_DAM_raw(run,25:end,bus_idx).* case_data_PD_DAM_raw(run,25:end,bus_idx);
    end


    for i=1:length(case_data_LMP(run,:,1)) - 95
        time_RT(i, 1) = start_time + (case_data_LMP(run,i+95,1)/86400);
    end
    
    for t_idx = 1:length(time_RT) - 95
        time_seconds = case_data_LMP(run,t_idx+95, 1);
        hour_idx = floor((time_seconds)/3600) + 1;
        DA_PD = case_data_PD_DAM_raw(run,hour_idx, 2:9);
        RT_PD = case_data_PD(run,t_idx+95, 2:9);
        DA_RT_Diff = RT_PD - DA_PD;
        RT_cost(t_idx, :) = DA_RT_Diff.*case_data_LMP(run,t_idx+95, 2:9)*RT_market_interval/3600;
        DA_RT_Diff_5 = RT_PD(:,:,6) - DA_PD(:,:,6);
        EV_cost(run,t_idx) = case_data_LMP(run,t_idx+95,6) .* case_data_EV(run,hour_idx,4)*(RT_market_interval/3600)*(4215/1e6);
    end
    
    total_DA_Market_cost = sum(sum(DA_cost),2);
    total_RT_Market_cost = sum(sum(RT_cost),2);
    total_cost = (total_DA_Market_cost + total_RT_Market_cost);
    total_cost_M = round(total_cost/1e6,3);
    Bus5_DA_cost = sum(DA_cost(:,6));
    Bus5_RT_cost = sum(RT_cost(:,5));
    Bus5_total_cost = Bus5_DA_cost + Bus5_RT_cost;
    total_EV_cost = sum(EV_cost(run,:));
    total_EV_cost_M = round(total_EV_cost/1e6,3);
    fprintf(char(Cases(run)));
    fprintf('\n');
    fprintf('Total Cost of Operation for DAM is %f, \n',total_DA_Market_cost);
    fprintf('Total Cost of Operation for RTM is %f, \n',total_RT_Market_cost);
    fprintf('Bus 5 Cost of Operation for DAM is %f, \n',Bus5_DA_cost);
    fprintf('Bus 5 Cost of Operation for RTM is %f, \n',Bus5_RT_cost);
    fprintf('Total Cost of Operation for ERCOT is %fM$, \n',total_cost_M);
    fprintf('Total Cost of EV Charging is %f$, \n',total_EV_cost);

end
