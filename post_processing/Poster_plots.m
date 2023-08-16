clc
clear all
close all

Cases = {'poly30','block30','Poly10','Poly20','Poly10m','Poly20m'};
fid = fopen('../src/wrapper_config.json'); 
raw = fread(fid,inf); 
str = char(raw'); 
fclose(fid); 
case_data = jsondecode(str);
start_time = datetime(case_data.start_time);


for i=1:length(Cases)
    casename = Cases(i);
    if i<3
        case_file_LMP = strcat('../outputs/',char(casename),'_RTM_LMP.csv');
        case_data_LMP(i,:,:) = readmatrix(case_file_LMP);
        case_file_PG = strcat('../outputs/',char(casename),'_RTM_PG.csv');
        case_data_PG(i,:,:) = readmatrix(case_file_PG);
        case_file_PD = strcat('../outputs/',char(casename),'_RTM_PD.csv');
        case_data_PD(i,:,:) = readmatrix(case_file_PD);
    else
        case_file2_LMP = strcat('../outputs/',char(casename),'_RTM_LMP.csv');
        
        case_data2_LMP(i-2,:,:) = readmatrix(case_file2_LMP);
        case_file2_PG = strcat('../outputs/',char(casename),'_RTM_PG.csv');
        case_data2_PG(i-2,:,:) = readmatrix(case_file2_PG);
        case_file2_PD = strcat('../outputs/',char(casename),'_RTM_PD.csv');
        case_data2_PD(i-2,:,:) = readmatrix(case_file2_PD);


        case_file2_LMP_DAM = strcat('../outputs/',char(casename),'_DAM_LMP.csv');
        case_data2_LMP_DAM_raw(i-2,:,:) = readmatrix(case_file2_LMP_DAM);
        case_file2_PG_DAM = strcat('../outputs/',char(casename),'_DAM_PG.csv');
        case_data2_PG_DAM_raw(i-2,:,:) = readmatrix(case_file2_PG_DAM);
        case_file2_PD_DAM = strcat('../outputs/',char(casename),'_DAM_PD.csv');
        case_data2_PD_DAM_raw(i-2,:,:) = readmatrix(case_file2_PD_DAM);

        if i==3
            case_data2_LMP_DAM = case_data2_LMP;
            case_data2_PG_DAM = case_data2_PG;
            case_data2_PD_DAM = case_data2_PD;
        end

        for a=1:size(case_data2_PD_DAM_raw,2)
            for b=1:12
                if ~((a==size(case_data2_PD_DAM_raw,2)) && (b==12))
                    for c = 2:9
                        case_data2_LMP_DAM(i-2,b+(12*(a-1)),c) = case_data2_LMP_DAM_raw(i-2,a,c);
                        case_data2_PG_DAM(i-2,b+(12*(a-1)),c) = case_data2_PG_DAM_raw(i-2,a,c);
                        case_data2_PD_DAM(i-2,b+(12*(a-1)),c) = case_data2_PD_DAM_raw(i-2,a,c);
                    end
                end
            end
        end
    end
end

time = case_data_LMP(1,:,1);
time = datetime((time/86400)+start_time);
time2 = case_data2_LMP(1,:,1);
time2 = datetime((time2/86400)+start_time);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%% LMP and Dispatch %%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
figure()
subplot(2,1,1)
plot(time,case_data_LMP(1,:,3))
hold on
plot(time,case_data_LMP(2,:,3))
title('Polynomial vs Block Bidding (30% flex)')
ylabel('Marginal Price ($/MW)')
legend({'Polynomial','Block'})
hold off

% subplot(3,1,2)
% plot(case_data_PG(1,:,1),case_data_PG(1,:,3))
% hold on
% plot(case_data_PG(2,:,1),case_data_PG(2,:,3))
% title('PG')
% hold off

subplot(2,1,2)
plot(time,case_data_PD(1,:,3))
hold on
plot(time,case_data_PD(2,:,3))
ylabel('Dispatch (MW)')
legend({'Polynomial','Block'})
hold off


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%% Bidding Difference %%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
figure()
p = load('/Users/jacobhastings/Desktop/WSU-Grad/Lab/Matpower/Matpower_wrapper/MATPOWER-wrapper/post_processing/poly_coeff.mat');
b = load('/Users/jacobhastings/Desktop/WSU-Grad/Lab/Matpower/Matpower_wrapper/MATPOWER-wrapper/post_processing/block_coeff.mat');
p = p.poly_coeff;
b = b.block_coeff;
for i=1:length(b)
    if mod(i,2) == 1
        bx(ceil(i/2)) = b(i);
    else
        by(i/2) = b(i);
    end
end
stairs(-1*bx,-1*by)
hold on
px = linspace(min(bx),max(bx));
plot(-1*px,-1*polyval(p,px))
xlabel('Flexible Load Reduction (MW)')
ylabel('Cost Reduction ($/hr)')

% 08/12 @3:50
PG_poly = -2945;
PG_block = -3683;

% 08/12 @12:00
PG_poly = -1683;
PG_block = -1387.8;


interval = 0;
for i=1:size(bx,2)
    if (PG_block < bx(i)) && (interval == 0)
        interval = i-1;
    end
end
PG_block_x = -1*PG_block;
PG_block_y = -1*by(interval);


plot(-1*PG_poly,-1*polyval(p,PG_poly),'O','MarkerSize',10,'MarkerEdgeColor','r')
plot(PG_block_x,PG_block_y,'O','MarkerSize',10,'MarkerEdgeColor','b')

legend({'Block','Polynomial'})
hold off

beginning = 1 + (288*2);    %Start later (2)
ending = 1439 - (288*1);    %End sooner  (1)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%% Effect of Mismatch %%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
figure()
subplot(2,1,1)
plot(time2(beginning:ending),case_data2_LMP_DAM(2,beginning:ending,3))
hold on
plot(time2(beginning:ending),case_data2_LMP(2,beginning:ending,3))
ylabel('Marginal Price ($/MW)')
title('Marginal Price (Coordinated)')
legend({'Day Ahead','Real time'})
hold off

subplot(2,1,2)
plot(time2(beginning:ending),case_data2_LMP_DAM(4,beginning:ending,3))
hold on
plot(time2(beginning:ending),case_data2_LMP(4,beginning:ending,3))
ylabel('Marginal Price ($/MW)')
title('Marginal Price (Uncoordinated)')
legend({'Day Ahead','Real time'})
hold off


% figure()
% for a = 2:9
%     plot(time2(beginning:ending),(case_data2_LMP_DAM(2,beginning:ending,a)-case_data2_LMP(2,beginning:ending,a)))
%     if a==2
%         hold on
%         title('Coordinated')
%     end
% end
% legend({'1','2','3','4','5','6','7','8'})
% hold off
% 
% figure()
% for a = 2:9
%     plot(time2(beginning:ending),(case_data2_LMP_DAM(4,beginning:ending,a)-case_data2_LMP(4,beginning:ending,a)))
%     if a==2
%         hold on
%         title('Uncoordinated')
%     end
% end
% legend({'1','2','3','4','5','6','7','8'})
% hold off


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%% Effect of Flex %%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
Base_LMP = readmatrix('../outputs/Base_RTM_LMP.csv');
time3 = Base_LMP(:,1);
time3 = datetime((time3/86400)+start_time);

figure()
% subplot(2,1,1)
plot(time3(beginning:ending-5),Base_LMP(beginning:ending-5,3))
hold on
plot(time2(beginning:ending),case_data2_LMP(1,beginning:ending,3))
plot(time2(beginning:ending),case_data2_LMP(2,beginning:ending,3))
ylabel('Marginal Price ($/MW)')
title('Effect of Flexible Loads on LMP')
legend({'Base','10%','20%'})
hold off

% subplot(2,1,2)
% plot(time2(beginning:ending),case_data2_LMP(1,beginning:ending,8))
% hold on
% plot(time2(beginning:ending),case_data2_LMP(2,beginning:ending,8))
% plot(time2(beginning:ending),case_data2_LMP(3,beginning:ending,8))
% ylabel('Marginal Price ($/MW)')
% title('Effect of Flexible loads on LMP (Bus 7)')
% legend({'Base','10%','20%'})
% hold off

