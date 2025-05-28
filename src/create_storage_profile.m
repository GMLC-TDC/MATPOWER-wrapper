function storage = create_storage_profile(storage_info)
%EX_STORAGE  Example Storage data file for stochastic unit commitment.

%   MOST
%   Copyright (c) 2015-2016, Power Systems Engineering Research Center (PSERC)
%   by Ray Zimmerman, PSERC Cornell
%
%   This file is part of MOST.
%   Covered by the 3-clause BSD License (see LICENSE file for details).
%   See https://github.com/MATPOWER/most for more info.

%%-----  storage  -----
% ecap = 100;              %% energy capacity
% pcap = ecap / 2;         %% power capacity
rho = 0;                 %% Optimization variable
scost = 0;               %% cost/value of initial/residual stored energy
%scost = 30;             %% cost/value of initial/residual stored energy
%scost2 = 41.6666667;    %% cost/value of initial/residual stored energy
%scost3 = 53.3333333;    %% cost/value of initial/residual stored energy
%% generator data
%	bus	Pg	Qg	Qmax	Qmin	Vg	mBase	status	Pmax	Pmin	Pc1	Pc2	Qc1min	Qc1max	Qc2min	Qc2max	ramp_agc	ramp_10	ramp_30	ramp_q	apf
for i=1:length(storage_info.ecap)
    storage_name = strcat('storage', string(1));
    storage.gen(i,:) = [storage_info.bus(i)	0	0	0	0	1	100	1	storage_info.pcap(i)	-storage_info.pcap(i)	0	0	0	0	0	0	storage_info.pcap(i)	storage_info.pcap(i)	storage_info.pcap(i)	0	0];
    storage.genfuel(i,:) = {'storage'};
end
% storage.gen = [
% %	1	0	0	0	0	1	100	1	pcap	-pcap	0	0	0	0	0	0	0	20	20	0	0;
% %	2	0	0	0	0	1	100	1	pcap	-pcap	0	0	0	0	0	0	0	20	20	0	0;
% 	bus	0	0	0	0	1	100	1	pcap	-pcap	0	0	0	0	0	0	0	20	20	0	0;
% ];

%%-----  OPF Data  -----%%
%% generator cost data
%	1	startup	shutdown	n	x1	y1	...	xn	yn
%	2	startup	shutdown	n	c(n-1)	...	c0
% storage.gencost = [
% 	bus	0	0	2	0	0   0;
% ];

%% xGenData
storage.xgd_table.colnames = {
	'CommitKey', ...
		'CommitSched', ...
			'PositiveActiveReservePrice', ...
				'PositiveActiveReserveQuantity', ...
					'NegativeActiveReservePrice', ...
						'NegativeActiveReserveQuantity', ...
							'PositiveActiveDeltaPrice', ...
								'NegativeActiveDeltaPrice', ...
									'PositiveLoadFollowReservePrice', ...
										'PositiveLoadFollowReserveQuantity', ...
											'NegativeLoadFollowReservePrice', ...
												'NegativeLoadFollowReserveQuantity', ...
};
for i=1:length(storage_info.ecap)
    storage_name = strcat('storage', string(1));
    storage.xgd_table.data(i,:) = [2	1	1e-8	2*storage_info.pcap(i)	2e-8	2*storage_info.pcap(i)  1e-9    1e-9	1e-6	2*storage_info.pcap(i)	1e-6	2*storage_info.pcap(i)];
end
% storage.xgd_table.data = [
% 	2	1	1e-8	2*pcap	2e-8	2*pcap	1e-9	1e-9	1e-6	2*pcap	1e-6	2*pcap;
% %	2	1	1e-8	2*pcap	2e-8	2*pcap	1e-9	1e-9	1e-6	2*pcap	1e-6	2*pcap;
% %	2	1	1e-8	2*pcap	2e-8	2*pcap	1e-9	1e-9	1e-6	2*pcap	1e-6	2*pcap;
% ];

%% StorageData
% storage.sd_table.OutEff				= eff;
% storage.sd_table.InEff				= eff;
% storage.sd_table.LossFactor			= 0;
% storage.sd_table.rho				= 0;
storage.sd_table.colnames = {
	'InitialStorage', ...
        'ExpectedTerminalStorageAim', ...
		    'InitialStorageLowerBound', ...
			    'InitialStorageUpperBound', ...
				    'InitialStorageCost', ...
					    'TerminalStoragePrice', ...
						    'MinStorageLevel', ...
							    'MaxStorageLevel', ...
								    'OutEff', ...
									    'InEff', ...
										    'LossFactor', ...
											    'rho', ...
};
for i=1:length(storage_info.ecap)
    storage_name = strcat('storage', string(1));
    storage.sd_table.data(i,:) = [storage_info.SOC(i)*storage_info.ecap(i) storage_info.SOC(i)*storage_info.ecap(i)   0	storage_info.ecap(i)	storage_info.scost(i)	storage_info.scost(i)	... 
                                    0	storage_info.ecap(i)    storage_info.eff(i)	 storage_info.eff(i)	0	rho];
end
% storage.sd_table.data = [
% 	0   0	0	ecap	scost	scost	0	ecap	eff	eff	0	1;
% %	0   50	0	ecap	scost	scost	0	ecap	1	1	0	0;
% %	0   0	0	ecap	scost3	scost3	0	ecap	1	1	0	0;
% ];