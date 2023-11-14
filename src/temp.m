clc
clear all

fname = '../system_data/ERCOT/ERCOT_8_system_v2.json';
fid = fopen(fname);
raw = fread(fid,inf);
str = char(raw');
fclose(fid);
mpc = jsondecode(str);


wind_data_2021 = readtable('../system_data/ERCOT/Hourly_Aggregated_Wind_Output_2021.xlsx');
solar_data_2021 = readtable('../system_data/ERCOT/Hourly_Aggregated_Solar_Output_2021.xlsx');

generation = {};
solar_gen(1,1) = string('time');
wind_gen(1,1) =  string('time');
s_idx = 2; w_idx = 2;

for k = 1:length(mpc.genfuel)
    generation.(mpc.genfuel{k, 1}).cap = 0;
    if mpc.genfuel{k, 1} == "solar"
      solar_gen(s_idx,1) = strcat("Gen",string(k));
      s_idx = s_idx + 1;
    end
    if mpc.genfuel{k, 1} == "wind"
      wind_gen(w_idx,1) = strcat("Gen",string(k));
      w_idx = w_idx + 1;
    end
    
end
for k = 1:length(mpc.genfuel)
    generation.(mpc.genfuel{k, 1}).cap = generation.(mpc.genfuel{k, 1}).cap + mpc.gen(k, 9);
end

solar_gen_data =  array2table(zeros(height(solar_data_2021),length(solar_gen)), 'VariableNames',solar_gen);
wind_gen_data =  array2table(zeros(height(solar_data_2021),length(wind_gen)), 'VariableNames',wind_gen);

seconds = int64(linspace(0, height(solar_data_2021)*3600, height(solar_data_2021)+1)');
solar_gen_data.time = seconds(1:end-1);
wind_gen_data.time = seconds(1:end-1);

s_idx = 2; w_idx = 2;
for k = 1:length(mpc.genfuel)
    if mpc.genfuel{k, 1} == "solar"
%         [val, solar_idx] = min(abs(etime(datevec(datenum(solar_data_2021.Time)), datevec(datenum(starttime)))));
        solar_value_2021_t = solar_data_2021.ERCOT_PVGR_GEN;
        solar_name =  strcat("Gen",string(k));
        solar_gen_data.(solar_name) = mpc.gen(k,9) * solar_value_2021_t / generation.("solar").cap;
        s_idx = s_idx + 1;
    end
    if mpc.genfuel{k, 1} == "wind"
        wind_value_2021_t = wind_data_2021.ERCOT_WIND_GEN;
        wind_name =  strcat("Gen",string(k));
        wind_gen_data.(wind_name) = mpc.gen(k,9) * wind_value_2021_t / generation.("wind").cap;
        w_idx = w_idx + 1;
    end

end

writetable(solar_gen_data, '2021_ERCOT_60min_Solar_Data_600_gen.csv' );
writetable(wind_gen_data, '2021_ERCOT_60min_Wind_Data_600_gen.csv' );
