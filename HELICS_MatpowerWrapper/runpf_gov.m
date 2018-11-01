function [MVAbase, bus, gen, branch, success, et]=runpf_gov(mpc, del_P, mpopt, fname, solvedcase)

%% if mpc.governor is not passed on then the governor assumes default parameters

if (isfield(mpc, 'governor')==0)
    mpc.governor(1,:)={'coal';0.00};
    mpc.governor(2,:)={'gas';0.05};
    mpc.governor(3,:)={'nuclear';0};
    mpc.governor(4,:)={'hydro';0.05};
end

R.coal=cell2mat(mpc.governor(1,2));
R.gas=cell2mat(mpc.governor(2,2));
R.nuclear=cell2mat(mpc.governor(3,2));
R.hydro=cell2mat(mpc.governor(4,2));

ramping_time=0.5; % half a minute
ramping_capacity=(mpc.gen(:,17).*(mpc.gen(:,9)))*(ramping_time/100);

%% ............. Getting indexes of fuel type if not passed as an input argument.............................................

%checking fuel type to get index
%checking generator status to make sure generator is active
%checking generator regulation value to make sure generator participates in governor action 

% if fuel type matrix is not available we will assume all generators are
% gas turbines

coal_idx=[];hydro_idx=[];nuclear_idx=[];gas_idx=[];governor_capacity=0;

if (isfield(mpc, 'genfuel'))
    for i=1:length(mpc.genfuel)
        if (cellstr(mpc.genfuel(i,1)) == "coal")  && (mpc.gen(i,8) == 1) && (R.coal ~= 0)
            coal_idx=[coal_idx i];
            governor_capacity = governor_capacity + mpc.gen(i,9)*(.05/R.coal);
        elseif (cellstr(mpc.genfuel(i,1)) == "gas") && (mpc.gen(i,8) == 1) && (R.gas ~= 0)
            gas_idx=[gas_idx i];
            governor_capacity = governor_capacity + mpc.gen(i,9)*(.05/R.gas);
        elseif (cellstr(mpc.genfuel(i,1)) == "nuclear") && (mpc.gen(i,8) == 1) && (R.nuclear ~= 0)
            nuclear_idx=[nuclear_idx i];
            governor_capacity = governor_capacity + mpc.gen(i,9)*(.05/R.nuclear);
        elseif (cellstr(mpc.genfuel(i,1)) == "hydro") && (mpc.gen(i,8) == 1) && (R.hydro ~= 0)
            hydro_idx=[hydro_idx i];
            governor_capacity = governor_capacity + mpc.gen(i,9)*(.05/R.hydro);
        end
    end
else
    gas_idx = find(mpc.gen(:,8) == 1)';
    governor_capacity =  sum(mpc.gen(gas_idx,9)*(.05/R.gas));
end
    
%% ..........................Sorting the generators based on capacity ..................................

gov_idx=[coal_idx hydro_idx nuclear_idx gas_idx]';
gov_R=[R.coal*ones(length(coal_idx),1);R.hydro.*ones(length(hydro_idx),1);R.nuclear*ones(length(nuclear_idx),1);R.gas*ones(length(gas_idx),1)];
capacity_idx=mpc.gen(gov_idx,9);
[~,I] = sort(capacity_idx);
Index=gov_idx(I);

%% ........................................... Governor Action ........................................

del_P_pu=del_P/governor_capacity;
del_f=.05*del_P_pu;

del_P_new=del_P;

k=1;l=1;m=1;
gen_update=mpc.gen(:,2);

for i=1:length(Index)

up_ramp_flag=0;
max_flag=0;
down_ramp_flag=0;
min_flag=0;


gen_update(Index(i),1)=mpc.gen(Index(i),2)+(mpc.gen(Index(i),9)*(del_f/(gov_R(I(i)))));

%.........................For Increasing Loads.............................

% Checking Ramp Rates
     if ((mpc.gen(Index(i),9)*(del_f/(gov_R(I(i))))) > ramping_capacity(Index(i),1))
            up_ramp_flag=1;
            gen_update(Index(i),1)=mpc.gen(Index(i),2)+ramping_capacity(Index(i),1);
            del_P_new=del_P_new-ramping_capacity(Index(i),1);
            governor_capacity=governor_capacity-(mpc.gen(Index(i),9)*(.05/(gov_R(I(i)))));
     end
% Checking generation Limits
     if (gen_update(Index(i),1) > mpc.gen(Index(i),9))
        max_flag=1;
        % both the limits are reached
        if (up_ramp_flag==1) && (max_flag==1)
            gen_update(Index(i),1)=mpc.gen(Index(i),9);
            del_P_new=del_P_new-(mpc.gen(Index(i),9)-mpc.gen(Index(i),2)) + ramping_capacity(Index(i),1);
            %Total_capacity already taken off in the ramp stage
            % only generationn capacity limit is reached   
        else
            gen_update(Index(i),1)=mpc.gen(Index(i),9);
            del_P_new=del_P_new-(mpc.gen(Index(i),9)-mpc.gen(Index(i),2));
            governor_capacity=governor_capacity-(mpc.gen(Index(i),9)*(.05/(gov_R(I(i)))));
        end
     end
    
%................................For Decreasing Loads.....................................     
     % checking for negative ramping

      if ((mpc.gen(Index(i),9)*(del_f/(gov_R(I(i))))) < -1*ramping_capacity(Index(i),1))
            down_ramp_flag=1;
            gen_update(Index(i),1)=mpc.gen(Index(i),2)-ramping_capacity(Index(i),1);
            del_P_new=del_P_new- (-1*ramping_capacity(Index(i),1));
            governor_capacity=governor_capacity-(mpc.gen(Index(i),9)*(.05/(gov_R(I(i)))));           
      end
     
     if (gen_update(Index(i),1) < mpc.gen(Index(i),10))
         min_flag=1;
         if (down_ramp_flag==1) && (min_flag==1)
            gen_update(Index(i),1)=mpc.gen(Index(i),10);
            del_P_new=del_P_new-(mpc.gen(Index(i),10)-mpc.gen(Index(i),2)) + (-1*ramping_capacity(Index(i),1));
            %Total_capacity already taken off in the ramp stage          
         % only generationn capacity limit is reached   
        else
            gen_update(Index(i),1)=mpc.gen(Index(i),10);
            del_P_new=del_P_new-(mpc.gen(Index(i),10)-mpc.gen(Index(i),2));
            governor_capacity=governor_capacity-(mpc.gen(Index(i),9)*(.05/(gov_R(I(i)))));           
        end
     end
     
  
    
del_P_pu=del_P_new/governor_capacity;
del_f=.05*del_P_pu;

end

% updating the generators
mpc.gen(:,2)=gen_update;

%% running power flow 
[MVAbase, bus, gen, branch, success, et] = runpf(mpc, mpopt, fname, solvedcase);

end