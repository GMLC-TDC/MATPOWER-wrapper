clc
clear all
close all

% addpath ('../src/')
% wrapper_startup;
% Wrapper = MATPOWERWrapper('../src/wrapper_config_v2.json', 0);
% Wrapper = Wrapper.read_profiles('load_profile_info', 'load_profile');
% Wrapper = Wrapper.read_profiles('wind_profile_info', 'wind_profile');
% Wrapper = Wrapper.read_profiles('solar_profile_info', 'solar_profile');

gens = [0,100,200,300,325,350,400,422,606];
cost_times= [85,97,124,148,198,428,443,509,502];
cap_times = [85,98,118,131,133,135,174,509,502];
plot(gens,cost_times)
hold on
grid on
plot(gens,cap_times)
ylabel('Time (Seconds)')
xlabel('Generators Included in UC')
title('Generator Reduction GUROBI')
legend({'By cost','By capacity'})
hold off
