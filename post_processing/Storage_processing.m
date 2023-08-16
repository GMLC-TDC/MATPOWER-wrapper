clc
clear all
close all

Cases = {'Base','BaseStg','BaseM','BaseStgM'};
fid = fopen('../src/wrapper_config.json'); 
raw = fread(fid,inf); 
str = char(raw'); 
fclose(fid); 
case_data = jsondecode(str);
start_time = datetime(case_data.start_time);
efficiency = 0.968;


for i=1:length(Cases)
    casename = Cases(i);
    
    case_file_LMP = strcat('../outputs/',char(casename),'_RTM_LMP.csv');
    %case_data_LMP(i,:,:) = readmatrix(case_file_LMP);
    case_file_PG = strcat('../outputs/',char(casename),'_RTM_PG.csv');
    %case_data_PG(i,:,:) = readmatrix(case_file_PG);
    case_file_PD = strcat('../outputs/',char(casename),'_RTM_PD.csv');
    %case_data_PD(i,:,:) = readmatrix(case_file_PD);

    if i==1
        Base_LMP = readmatrix(case_file_LMP);
        Base_PG = readmatrix(case_file_PG);
        Base_PD = readmatrix(case_file_PD);
    elseif i==2
        Stor_LMP = readmatrix(case_file_LMP);
        Stor_PG = readmatrix(case_file_PG);
        Stor_PD = readmatrix(case_file_PD);
    elseif i==3
        BaseM_LMP = readmatrix(case_file_LMP);
        BaseM_PG = readmatrix(case_file_PG);
        BaseM_PD = readmatrix(case_file_PD);
    elseif i==4
        StorM_LMP = readmatrix(case_file_LMP);
        StorM_PG = readmatrix(case_file_PG);
        StorM_PD = readmatrix(case_file_PD);
    end
end

charge = zeros(size(Stor_PG,1),1);
if Stor_PG(1,112)>=0
    charge(1) = (-1*Stor_PG(1,112)/12)/efficiency;
else
    charge(1) = (-1*Stor_PG(1,112)/12)*efficiency;
end

for i = 2:size(charge,1)
    if Stor_PG(i,112)>=0    %Discharging
        charge(i) = charge(i-1) + ((-1*Stor_PG(i,112)/12)/efficiency);
    else                    %Charging
        charge(i) = charge(i-1) + ((-1*Stor_PG(i,112)/12)*efficiency);
    end
end

profit = zeros(size(Stor_PG,1),1);
profit(1) = Stor_LMP(1,3) * Stor_PG(1,112) / 12;
for i = 2:size(profit,1)
    profit(i) = profit(i-1) + (Stor_LMP(i,3) * Stor_PG(i,112) / 12);
end

time = Base_LMP(:,1);
time = datetime((time/86400)+start_time);

profitM = zeros(size(StorM_PG,1),1);
profitM(1) = StorM_LMP(1,3) * StorM_PG(1,112) / 12;
for i = 2:size(profitM,1)
    profitM(i) = profitM(i-1) + (StorM_LMP(i,3) * StorM_PG(i,112) / 12);
end
timeM = BaseM_LMP(:,1);
timeM = datetime((timeM/86400)+start_time);


subplot(3,1,1)
plot(time,Base_LMP(:,3))
hold on
plot(time,Stor_LMP(:,3))
legend({'Base','Storage'})
title('LMPs With and Without Storage')
xlabel('Time')
ylabel('LMP ($/MWh)')
hold off

subplot(3,1,2)
plot(time,charge)
hold on
title('Current Charge in Storage')
xlabel('Time')
ylabel('Charge (MWh)')
hold off

subplot(3,1,3)
plot(time,profit)
hold on
title('Current Profit')
xlabel('Time')
ylabel('Profit ($)')
hold off

figure()
plot(timeM,profitM)
hold on
title('Current Profit (August)')
xlabel('Time')
ylabel('Profit ($)')
hold off