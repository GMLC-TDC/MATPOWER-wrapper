%STARTUP
%% add MATPOWER paths

if exist('OCTAVE_VERSION', 'builtin') ~= 0
    MATPOWER_start_up_path = '/home/helics-user/Projects/matpower7.1/startup.m';
end
% MATPOWER_start_up_path = 'C:\Users\mukh915\matpower8.0b1\startup.m';
% MATPOWER_start_up_path = '/home/helics-user/Projects/HELICS_Plus/matpower7.1/matpower_startup.m';
MATPOWER_start_up_path = 'C:\Users\mukh915\matpower8.0b1\startup.m';
% MATPOWER_start_up_path = 'C:\Users\jw.hastings\Documents\matpower7.1\startup.m';
% MATPOWER_start_up_path = '/Users/jacobhastings/Desktop/WSU-Grad/Lab/Matpower/matpower7.1/startup.m';

run(MATPOWER_start_up_path)

%% add HELICS paths
% addpath('/home/helics-user/Softwares_user/helics_v3_install/octave');

% libraryName = 'C:\Users\jw.hastings\OneDrive - Washington State University (email.wsu.edu)\Documents\matHELICS\matHELICS\helics.dll';
% headerName = 'C:\Users\jw.hastings\OneDrive - Washington State University (email.wsu.edu)\Documents\matHELICS\matHELICS\helics_minimal.h';

% libraryName = 'C:\Users\mukh915\matHELICS\helics\helics.dll';
% headerName = 'C:\Users\mukh915\matHELICS\helics\include\helics_minimal.h';

% helicsStartup(libraryName, headerName)
% addpath('C:\Users\mukh915\matHELICS\helics\')
% addpath('C:\Users\jw.hastings\OneDrive - Washington State University (email.wsu.edu)\Documents\matHELICS\matHELICS')

%% add Mosek paths
% addpath('C:\Program Files\Mosek\10.0\toolbox\r2017a')
% addpath('C:\Program Files\Mosek\10.0\toolbox\r2017aom')
% libraryName = 'C:\Users\mukh915\matHELICS\helics\helics.dll';
% headerName = 'C:\Users\mukh915\matHELICS\helics\include\helics_minimal.h';

% helicsStartup(libraryName, headerName)
% addpath('C:\Users\mukh915\matHELICS\helics\')
% addpath('C:\Users\jw.hastings\OneDrive - Washington State University (email.wsu.edu)\Documents\matHELICS\matHELICS')

%% add Mosek paths
addpath('C:\Program Files\Mosek\10.0\toolbox\r2017a')
addpath('C:\Program Files\Mosek\10.0\toolbox\r2017aom')
% addpath('/Users/jacobhastings/Desktop/WSU-Grad/Lab/MOSEK/mosek/10.0/toolbox/r2017a')
% addpath('/Users/jacobhastings/Desktop/WSU-Grad/Lab/MOSEK/mosek/10.0/toolbox/r2017aom')


