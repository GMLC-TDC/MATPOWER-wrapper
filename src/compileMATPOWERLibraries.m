% This script compiles certain MATPOWER functions into precompiled libraries that can be used in c/c++ 
% applications

%Created April 2, 2017 by Jacob Hansen (jacob.hansen@pnnl.gov)

%Copyright (c) 2008 Battelle Memorial Institute.  The Government retains a paid-up nonexclusive, irrevocable
%worldwide license to reproduce, prepare derivative works, perform publicly and display publicly by or for the
%Government, including the right to distribute to other Government contractors.

clear
clc

% path to where you want the outputs
outputPath = '/Users/hans464/Documents/PNNL/Projects/FY18/CCSI - Integrated Control Testing/populationScripts/modelDependency/transmission/wrapper';
% path to the MATPOWER distribution you are using
matpowerPath = '/Users/hans464/Documents/MATLAB/';
% path to the MATPOWER govenor fuction
govenorPath = '/Users/hans464/Documents/PNNL/Projects/FY18/CCSI - Integrated Control Testing/populationScripts/modelDependency/transmission/wrapper';
% version of MATPOWER you are using
matpowerVersion = 'matpower6.0';

% compile the libraries
mcc_string2 = ['mcc -W cpplib:libMATPOWER -T link:lib -v -d ',outputPath, ' -I ',govenorPath, ' -I ',matpowerPath,matpowerVersion,' runpf.m runopf.m mpoption.m runpf_gov.m']; 
eval(mcc_string2);