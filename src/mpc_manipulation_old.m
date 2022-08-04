function functions = mpc_manipulation
    functions.update_loads_from_profiles=@update_loads_from_profiles;
    functions.update_VRE_from_profiles  =@update_VRE_from_profiles;
end

function mpc_case = update_loads_from_profiles(mpc_case, load_profile_info, profiles, time)
    profile_row = find(time==profiles(:,1));
    profile_col_idx = load_profile_info.data_map.columns;
    profile_bus_idx = load_profile_info.data_map.bus;
    kW_kVAR_ratio = mpc_case.bus(:,3)./ mpc_case.bus(:,4);
    mpc_case.bus(profile_bus_idx, 3) = profiles(profile_row, profile_col_idx)';
    mpc_case.bus(profile_bus_idx, 4) = mpc_case.bus(profile_bus_idx, 3) ./ kW_kVAR_ratio; 
    
end


function mpc_case = update_VRE_from_profiles(mpc_case, VRE_profile_info, profiles, time)
    profile_row = find(time==profiles(:,1));
    profile_col_idx = VRE_profile_info.data_map.columns;
    profile_gen_idx = VRE_profile_info.data_map.gen;
    mpc_case.gen(profile_gen_idx, 9) = profiles(profile_row, profile_col_idx)';   
end