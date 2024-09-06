clc
clear all
pf = 0.85;
% 3^2 + 4^2 = kvar  pf = 3/kvar
mpc = loadcase('test_damcase.m');
mpc.bus(:,4) = mpc.bus(:,3).*tan(acos(pf));
mpc.genfuel = repmat('unknown',size(mpc.gen,1),1);
str = jsonencode (mpc);
   fid = fopen('test_damcase.json', 'w'); 
   fwrite(fid, str);
   fclose(fid);