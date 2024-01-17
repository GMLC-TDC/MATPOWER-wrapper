clc
clear all
close all

Cases = {'Base','Flex10','Flex20','Mis10','Mis20'};
fid = fopen('../src/wrapper_config_v2.json'); 
raw = fread(fid,inf); 
str = char(raw'); 
fclose(fid); 
case_data = jsondecode(str);
start_time = datetime(case_data.start_time);


for i=1:length(Cases)
    casename = Cases(i);
    case_file_LMP = strcat('../outputs/',char(casename),'_RTM_LMP.csv');
    case_data_LMP(i,:,:) = readmatrix(case_file_LMP);
    case_file_PG = strcat('../outputs/',char(casename),'_RTM_PG.csv');
    case_data_PG(i,:,:) = readmatrix(case_file_PG);
    case_file_PD = strcat('../outputs/',char(casename),'_RTM_PD.csv');
    case_data_PD(i,:,:) = readmatrix(case_file_PD);

    case_file_LMP_DAM = strcat('../outputs/',char(casename),'_DAM_LMP.csv');
    case_data_LMP_DAM_raw(i,:,:) = readmatrix(case_file_LMP_DAM);
    case_file_PG_DAM = strcat('../outputs/',char(casename),'_DAM_PG.csv');
    case_data_PG_DAM_raw(i,:,:) = readmatrix(case_file_PG_DAM);
    case_file_PD_DAM = strcat('../outputs/',char(casename),'_DAM_PD.csv');
    case_data_PD_DAM_raw(i,:,:) = readmatrix(case_file_PD_DAM);
end

time = case_data_LMP(1,:,1);
time = datetime((time/86400)+start_time);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%% Effect of Flex %%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% LMP
figure()
%%%%%%%%%%%% BUS 2 %%%%%%%%%%%%%%%
subplot(3,1,1)
bus = 2;
plot(time,case_data_LMP(1,:,bus+1))
hold on
grid on
plot(time,case_data_LMP(2,:,bus+1))
plot(time,case_data_LMP(3,:,bus+1))

ylabel('Marginal Price ($/MW)')
title('Effect of Flexible Loads on LMP (Bus 2)')
legend({'Base','10%','20%'},"Location","southwest")
hold off

%%%%%%%%%%%% BUS 5 %%%%%%%%%%%%%%%
subplot(3,1,2)
bus = 5;
plot(time,case_data_LMP(1,:,bus+1))
hold on
grid on
plot(time,case_data_LMP(2,:,bus+1))
plot(time,case_data_LMP(3,:,bus+1))

ylabel('($/MW)')
title('Effect of Flexible Loads on LMP (Bus 5)')
legend({'Base','10%','20%'},"Location","southwest")
hold off

%%%%%%%%%%%% BUS 1 %%%%%%%%%%%%%%%
subplot(3,1,3)
bus = 1;
plot(time,case_data_LMP(1,:,bus+1))
hold on
grid on
plot(time,case_data_LMP(2,:,bus+1))
plot(time,case_data_LMP(3,:,bus+1))

ylabel('($/MW)')
title('Effect of Flexible Loads on LMP (Bus 1)')
legend({'Base','10%','20%'},"Location","southwest")
hold off


%%%%%%%%%%%%%% Dispatch %%%%%%%%%%%%%%
% figure()
% plot(time,case_data_PD(1,:,3))
% hold on
% plot(time,case_data_PD(2,:,3))
% plot(time,case_data_PD(3,:,3))
% 
% ylabel('Dispatch (MW)')
% title('Effect of Flexible Loads on Dispatch')
% legend({'Base','10%','20%'})
% hold off




%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%% Effect of Mismatch %%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
case_data_LMP_DAM = zeros(size(case_data_LMP,1),size(case_data_LMP,2),size(case_data_LMP,3));
for a=1:size(case_data_LMP,2)
    b = floor(a/12) +1;
    case_data_LMP_DAM(:,a,:) = case_data_LMP_DAM_raw(:,b,:);
end

figure()
plot(time,case_data_LMP(5,:,3))
hold on
grid on
plot(time,case_data_LMP_DAM(5,:,3))
ylabel('Marginal Price ($/MW)')
title('Effect of DA-RT Coordination on LMP')
legend({'RTM','DAM'})
hold off

LMP_spread(:,:) = case_data_LMP(5,:,2:9) - case_data_LMP_DAM(5,:,2:9);
spread_max = max(max(abs(LMP_spread)));

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%% Base LMP all Bus %%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% figure()
% plot(time,case_data_LMP(1,:,2))
% hold on
% for i=3:9
%     plot(time,case_data_LMP(1,:,i))
% end
% ylabel('Marginal Price ($/MW)')
% title('LMPs at each bus')
% legend({'Bus 1','Bus 2','Bus 3','Bus 4','Bus 5','Bus 6','Bus 7','Bus 8'})
% hold off