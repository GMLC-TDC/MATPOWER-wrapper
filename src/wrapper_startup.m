%STARTUP

%% add MATPOWER paths

% MATPOWER_start_up_path = '/home/helics-user/Projects/HELICS_Plus/matpower7.1/matpower_startup.m';
% MATPOWER_start_up_path = 'C:\Users\jw.hastings\Documents\matpower7.1\startup.m';
% run(MATPOWER_start_up_path)

%% add HELICS paths
% addpath('/home/helics-user/Softwares_user/helics_v3_install/octave');

%libraryName = 'C:\Users\mukh915\matHELICS\helics\helics.dll';
libraryName = 'C:\Users\jw.hastings\OneDrive - Washington State University (email.wsu.edu)\Documents\matHELICS\matHELICS\helics.dll';
%headerName = 'C:\Users\mukh915\matHELICS\helics\include\helics_minimal.h';
headerName = 'C:\Users\jw.hastings\OneDrive - Washington State University (email.wsu.edu)\Documents\matHELICS\matHELICS\helics_minimal.h';

helicsStartup(libraryName, headerName)
addpath('C:\Users\mukh915\matHELICS\helics\')
addpath('C:\Users\jw.hastings\OneDrive - Washington State University (email.wsu.edu)\Documents\matHELICS\matHELICS')