clc
clear all
clear classes
close all

Cases = {'Base', 'Flex25'};
case_data = read_json('../src/wrapper_config.json');
start_time = datetime(case_data.start_time)

linS = {'-','--',':'};
%% Compare LMPs %%
figure
a=axes();
set(a,'Units','normalized');

for case_idx = 1:length(Cases)
    casename = Cases{case_idx};
    case_file_LMP = strcat('../outputs/',casename,'_RTM_LMP.csv');
    case_data_LMP = readmatrix(case_file_LMP);
    time_data = start_time + seconds(case_data_LMP(:,1));
    plot(time_data,case_data_LMP(:,2:end),linS{case_idx},'LineWidth',1.5)
    hold on
end
ylabel(a,'LMP profile ($/MW)','FontSize',14);
set(gca, 'FontName', 'Times New Roman')
xlabel(a,'Time of Day (Hr)','FontSize',14)
set(gca, 'FontName', 'Times New Roman')
grid on 



%% Compare Dispatchable Loads %%%
figure
a=axes();
set(a,'Units','normalized');
Legend=cell(10,1);
co_sim_buses = case_data.cosimulation_bus;
ref = .25;
iter = 1
for case_idx = 1:length(Cases)
    casename = Cases{case_idx};
    case_file_PD = strcat('../outputs/',casename,'_RTM_PD.csv');
    case_data_PD = readmatrix(case_file_PD);
    time_data = start_time + seconds(case_data_PD(:,1));

    for idx =1:length(co_sim_buses) 
        co_sim_bus = co_sim_buses(idx);
        plot(time_data,case_data_PD(:,co_sim_bus+1),linS{case_idx},'LineWidth',1.5)
        hold on 
        if strfind(casename,'Base')
            plot(time_data,case_data_PD(:,co_sim_bus+1)*(1-ref),linS{case_idx},'LineWidth',1.5)
        end
        Legend{iter}=strcat(casename,'- Bus:', num2str(co_sim_bus));
        iter = iter+1;
    end
    
end
legend(Legend(1:iter-1))
ylabel(a,'Net DSO Demand (MW)','FontSize',14);
set(gca, 'FontName', 'Times New Roman')
xlabel(a,'Time of Day (Hr)','FontSize',14)
set(gca, 'FontName', 'Times New Roman')
grid on 

case_file_PG = strcat('../outputs/',casename,'_RTM_PG.csv');
case_data_PG = readmatrix(case_file_PG);


function val = read_json(file)
           fid = fopen(file); 
           raw = fread(fid,inf); 
           str = char(raw'); 
           fclose(fid); 
           val = jsondecode(str);
end 

