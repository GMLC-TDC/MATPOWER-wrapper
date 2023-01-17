clc
clear all
clear classes
close all


case_data = read_json('../src/wrapper_config.json');
casename = 'Base_Feb';
month = 'February 2016';
start_time = datetime(case_data.start_time);
% start_time = datetime('2016-08-01');

model_file = strcat(case_data.matpower_most_data.datapath, case_data.matpower_most_data.case_name);
model_data = read_json(model_file);

figure
a=axes();
set(a,'Units','normalized');
case_file_LMP = strcat('../outputs/',casename,'_RTM_LMP.csv');
case_data_LMP = readmatrix(case_file_LMP);
time_data = start_time + seconds(case_data_LMP(:,1));
plot(time_data,case_data_LMP(:,2:end),'-','LineWidth',1.5)
legend({'Bus1','Bus2','Bus3', 'Bus4', 'Bus5', 'Bus6', 'Bus7', 'Bus8'});
ylabel(a,'LMP profile ($/MW)','FontSize',14);
set(gca, 'FontName', 'Times New Roman')
xlabel(a,'Time of Day (Hr)','FontSize',14)
set(gca, 'FontName', 'Times New Roman')
grid on 




gen_mix_type = {'nuclear','coal','gas_cc','gas','wind'};
newcolors = [0.5 0.5 0.5; 0 0 0; 1 .65 0; 1 0.58 0; 0 0 1];

%% Creating Gen Mix Category %%
for i = 1:length(model_data.genfuel)
    genfuel{i,1} = model_data.genfuel{i}{1};
     if strfind(model_data.genfuel{i}{2}, 'Combined Cycle')
         genfuel{i,1} = strcat(genfuel{i,1}, '_cc');
     end
    
end

% gen_mix_type = unique(genfuel);

gen_idx = struct()
for type_idx = 1:length(gen_mix_type)
    type = gen_mix_type(type_idx);
    gen_idx.(type{1}) = find(strcmp(genfuel, type{1}));
end

    
%% Reading OPF Solutions %%

case_file_PG = strcat('../outputs/',casename,'_RTM_PG.csv');
case_data_PG = readmatrix(case_file_PG);


time_data = start_time + seconds(case_data_PG(:,1));

for type_idx = 1:length(gen_mix_type)
    type = gen_mix_type(type_idx);
    gen_type_indexes = gen_idx.(type{1})+1; %% adding +1 for as the data is moved by +1 due to time 
    gen_mix_data(:, type_idx) = sum(case_data_PG(:, gen_type_indexes), 2);
    Legend{type_idx}=type{1};
end


figure
a=axes();
set(a,'Units','normalized');
area(time_data',gen_mix_data, 'LineWidth',1.25)
colororder(newcolors)
legend(Legend)
a.YAxis.Exponent = 0;
ylabel(a,'Net Generation (MW)','FontSize',14);
set(gca, 'FontName', 'Times New Roman')
xlabel(a,'Time of Day (Hr)','FontSize',14)
set(gca, 'FontName', 'Times New Roman')
xlim([time_data(1),time_data(end)])
grid on 
title('Simulated ERCOT Gen Mix from Wrapper')


input_file_name = strcat(case_data.matpower_most_data.datapath, 'ERCOTGenByFuel2016.xlsx');
ERCOT_actual_gen_mix_data_raw = readtable(input_file_name,'Sheet', month, 'Format','auto');
ERCOT_actual_gen_mix_data_raw.Time.Format = 'yyyy-MM-dd hh:mm';
ERCOT_actual_gen_mix_data = ERCOT_actual_gen_mix_data_raw(isbetween(ERCOT_actual_gen_mix_data_raw.Time, time_data(1), time_data(end)), :);
vars = ERCOT_actual_gen_mix_data.Properties.VariableNames;

for type_idx = 1:length(gen_mix_type)    
    type = gen_mix_type(type_idx);
    type_idx_actual_data(type_idx) =  find(strcmp(lower( vars ), type{1}));
end

ERCOT_actual_data_select_gen_type = ERCOT_actual_gen_mix_data(:,type_idx_actual_data);
figure
a=axes();
set(a,'Units','normalized');
area(ERCOT_actual_gen_mix_data.Time,ERCOT_actual_data_select_gen_type{:,:}*4, 'LineWidth',1.25)
colororder(newcolors)
legend(Legend)
ylabel(a,'Net Generation (MW)','FontSize',14);
a.YAxis.Exponent = 0;
set(gca, 'FontName', 'Times New Roman')
xlabel(a,'Time of Day (Hr)','FontSize',14)
xlim([ERCOT_actual_gen_mix_data.Time(1),ERCOT_actual_gen_mix_data.Time(end)])
set(gca, 'FontName', 'Times New Roman')
grid on 
title('Actual ERCOT Gen Mix from Settlement Data')


function val = read_json(file)
       fid = fopen(file); 
       raw = fread(fid,inf); 
       str = char(raw'); 
       fclose(fid); 
       val = jsondecode(str);
end 