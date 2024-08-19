clc
clear all



addpath ('../src/')
wrapper_startup;
Wrapper = MATPOWERWrapper('../src/wrapper_config_v2.json', 0);
% UCBase, UCStor, UCFlex10, UCFlex20, UCMis10, UCMis20
% Casenames = {'Base','Flex10','Flex20','Mis10','Mis20', 'UCBase', 'UCFlex10', 'UCFlex20', 'UCMis10', 'UCMis20'};
Casenames = {'Base','UCBase','Flex10','UCFlex10','Flex20','UCFlex20','Mis10','UCMis10','Mis20','UCMis20'};

for C=1:length(Casenames)
    % Cases = {'Base'};  %Base, Flex10, Flex20, Mis10, Mis20
    Cases = Casenames(C);
    fprintf('\n');
    fprintf(cell2mat(Casenames(C)));
    fprintf('\n');
    
    
    fid = fopen('../src/wrapper_config_v2.json'); 
    raw = fread(fid,inf); 
    str = char(raw'); 
    fclose(fid); 
    case_data = jsondecode(str);
    start_time = datetime(case_data.start_time);
    end_time = datetime(case_data.end_time);
    
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
    
    
    for bus_idx = 2:9
        DA_cost(:, bus_idx) = case_data_LMP_DAM_raw(:,bus_idx).* case_data_PD_DAM_raw(:,bus_idx);
    end
    
    for t_idx = 1:length(time_RT)
        time_seconds = case_data_RT_LMP(t_idx, 1);
        hour_idx = floor((time_seconds)/3600) + 1;
        DA_PD = case_data_PD_DAM_raw(hour_idx, 2:9);
        RT_PD = case_data_RT_PD(t_idx, 2:9);
        DA_RT_Diff = RT_PD - DA_PD;
        RT_cost(t_idx, :) = DA_RT_Diff.*case_data_RT_LMP(t_idx, 2:9)*Wrapper.config_data.real_time_market.interval/3600;
    end
    
    
    total_DA_Market_cost = sum(sum(DA_cost),2);
    total_RT_Market_cost = sum(sum(RT_cost),2);
    total_cost = (total_DA_Market_cost + total_RT_Market_cost);
    total_cost_M(C) = round(total_cost/1e6,3);
    fprintf('Total Cost of Operation for DAM is %.2f, \n',total_DA_Market_cost);
    fprintf('Total Cost of Operation for RTM is %.2f, \n',total_RT_Market_cost);
    fprintf('Total Cost of Operation for ERCOT is %.3fM$, \n',total_cost_M(C));
    
    peak_load =  max(sum(case_data_RT_PD(:, 2:9),2))/1e3;
    fprintf('Peak Load is %.2fGW, \n',peak_load);
    
    
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
    
    
    Coal_gen_MWH(C) =  sum(sum(case_data_RT_PG(:, Coal_idx' +1), 2))*Wrapper.config_data.real_time_market.interval/3600;
    NG_CC_gen_MWH(C) = sum(sum(case_data_RT_PG(:, NG_CC_idx' +1), 2))*Wrapper.config_data.real_time_market.interval/3600;
    NG_SC_gen_MWH(C) = sum(sum(case_data_RT_PG(:, NG_SC_idx' +1), 2))*Wrapper.config_data.real_time_market.interval/3600;
    
    total_Sh(C) = NG_CC_gen_MWH(C)*ston_C02_Coal + NG_CC_gen_MWH(C)*ston_C02_NG_CC + NG_SC_gen_MWH(C)*ston_C02_NG_SC;
    fprintf('Total ShortTons of Co2 is %fST, \n',total_Sh(C));
    
    total_energy_MWH(C)  =  sum(sum(case_data_RT_PD(:, 2:9)))*Wrapper.config_data.real_time_market.interval/3600;
    average_energy_cost(C) = total_cost/total_energy_MWH(C);
    fprintf('Average Cost of Energy is %f$/MWH, \n',average_energy_cost(C));

end

labels=["Base" "10% (DAM-RTM)" "20% (DAM-RTM)" "10% (RTM)" "20% (RTM)"];
bar_avg_cost = zeros(5,2);
bar_total_sh = zeros(5,2);
bar_total_cost = zeros(5,2);
for i=1:5
    bar_avg_cost(i,1) = average_energy_cost((2*i)-1);
    bar_avg_cost(i,2) = average_energy_cost(2*i);
    bar_total_sh(i,1) = total_Sh((2*i)-1);
    bar_total_sh(i,2) = total_Sh(2*i);
    bar_total_cost(i,1) = total_cost_M((2*i)-1);
    bar_total_cost(i,2) = total_cost_M(2*i);
end

bar_diff_sh = bar_total_sh(:,2) - bar_total_sh(:,1);
bar_diff_cost = bar_avg_cost(:,2) - bar_avg_cost(:,1);
bar_diff_tcost = bar_total_cost(:,2) - bar_total_cost(:,1);

figure()
subplot(2,1,1)
bar(bar_avg_cost)
hold on
grid on
title('Average Energy Cost')
ylabel('$/MWHr')
set(gca,'xticklabel',labels)
legend({'Without UC','With UC'},'Location','southeast')
hold off

subplot(2,1,2)
bar(bar_diff_cost)
hold on
grid on
title('Average Cost Change with UC (UC - non UC)')
ylabel('$/MWHr')
set(gca,'xticklabel',labels)
hold off

figure()
subplot(2,1,1)
bar(bar_total_sh)
hold on
grid on
title('Total Tons of CO2')
ylabel('CO2 (T)')
set(gca,'xticklabel',labels)
legend({'Without UC','With UC'},'Location','southeast')
hold off

subplot(2,1,2)
bar(bar_diff_sh)
hold on
grid on
title('CO2 Change with UC (UC - non UC)')
ylabel('CO2 (T)')
set(gca,'xticklabel',labels)
hold off

figure()
subplot(2,1,1)
bar(bar_total_cost)
hold on
grid on
title('Total Cost of Operation to ERCOT')
ylabel('Cost (M$)')
set(gca,'xticklabel',labels)
legend({'Without UC','With UC'},'Location','southeast')
hold off

subplot(2,1,2)
bar(bar_diff_tcost)
hold on
grid on
title('Total Cost Change with UC (UC - non UC)')
ylabel('Cost (M$)')
set(gca,'xticklabel',labels)
hold off