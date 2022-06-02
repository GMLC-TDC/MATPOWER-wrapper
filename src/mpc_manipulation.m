function functions = mpc_manipulation
    functions.update_loads=@update_loads;
end

function mpc_case = update_loads(mpc_case, load_profile_info, profiles, time)
    profile_row = find(time==profiles(:,1));
    profile_col_idx = load_profile_info.columns_bus_map.columns;
    profile_bus_idx = load_profile_info.columns_bus_map.bus;
    kW_kVAR_ratio = mpc_case.bus(:,3)./ mpc_case.bus(:,4);
    mpc_case.bus(profile_bus_idx, 3) = profiles(profile_row, profile_col_idx)';
    mpc_case.bus(profile_bus_idx, 4) = mpc_case.bus(profile_bus_idx, 3) ./ kW_kVAR_ratio; 
    
end