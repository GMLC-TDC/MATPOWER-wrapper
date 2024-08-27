clc
clear all
clear classes
close all

% Cases = {'Base','Poly10','Poly25'};
Cases = {'Base_new_v2','storage_v2'};
case_data = read_json('../src/wrapper_config_v2.json');
start_time = datetime(case_data.start_time)

linS = {'-','--',':'};
%% Compare LMPs %%
figure
p2 = subplot(2,1,1);
for case_idx = 1:length(Cases)
    casename = Cases{case_idx};
    case_file_LMP = strcat('../outputs/',casename,'_RTM_LMP.csv');
    case_data_LMP = readmatrix(case_file_LMP);
    time_data = start_time + seconds(case_data_LMP(:,1));
    plot(time_data,case_data_LMP(:,3),'LineWidth',1.5)
    hold on
end
legend({'Base','Storage'},"Location","southwest")
ylabel(p2,'DA-LMP ($/MWHr)','FontSize',12);
% set(gca, 'FontName', 'Helvetica')
xlabel(p2,'Time of Day (Hr)','FontSize',12)
% set(gca, 'FontName', 'Helvetica')
grid on 
%legend('0%','polynomial(10%)','Polynomial(25%)')

p1 = subplot(2,1,2);
set(p1,'Units','normalized');
for case_idx = 1:length(Cases)
    casename = Cases{case_idx};
    case_file_LMP = strcat('../outputs/',casename,'_DAM_LMP.csv');
    case_data_LMP = readmatrix(case_file_LMP);
    time_data = start_time + seconds(case_data_LMP(:,1));
    plot(time_data,case_data_LMP(:,3),'LineWidth',1.5)
    hold on
end
legend({'Base','Storage'},"Location","southwest")
ylabel(p1,'RT-LMP ($/MWHr)','FontSize',12);
set(gca, 'FontName', 'Helvetica')
xlabel(p1,'Time of Day (Hr)','FontSize',12)
set(gca, 'FontName', 'Helvetica')
grid on 

%% Plot Storage
if   case_data.include_storage
    casename = 'storage_v2';
    case_file_P_storage = strcat('../outputs/',casename,'_RTM_P_storage.csv');
    case_data_P_storage = readmatrix(case_file_P_storage);
    case_file_SoC_storage = strcat('../outputs/',casename,'_RTM_SoC_storage.csv');
    case_data_SoC_storage = readmatrix(case_file_SoC_storage);
    time_data = start_time + seconds(case_data_P_storage(:,1));
    case_file_PD = strcat('../outputs/',casename,'_RTM_PD.csv');
    case_data_PD = readmatrix(case_file_PD);

    figure 
    a=axes();
    set(a,'Units','normalized');
    yyaxis left
    plot(time_data,case_data_P_storage(:,2),'LineWidth',1.5)
    legend({'Base','Storage'},"Location","southwest")
    ylabel(a,'Storage Dispatch (MW)','FontSize',12);
    set(gca, 'FontName', 'Helvetica')
    xlabel(a,'Time of Day (Hr)','FontSize',12)
    ylim([-500, 500])
    yyaxis right
%     plot(time_data,case_data_SoC_storage(:,2)./500,'LineWidth',1.5)
     plot(time_data,sum(case_data_PD(:,2:end),2)/1000,'LineWidth',1.5)
     hold on
     plot(time_data,(sum(case_data_PD(:,2:end),2) - sum(case_data_P_storage(:,2:end), 2)) /1000,'LineWidth',2)
    legend({'Base','Storage'},"Location","southwest")
    ylabel(a,'Storage SoC (p.u.','FontSize',12);
    set(gca, 'FontName', 'Helvetica')
    xlabel(a,'Time of Day (Hr)','FontSize',12)
end
    
    set(gca, 'FontName', 'Helvetica')
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
%         if strfind(casename,'Base')
%             plot(time_data,case_data_PD(:,co_sim_bus+1)*(1-ref),linS{case_idx},'LineWidth',1.5)
%         end
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

