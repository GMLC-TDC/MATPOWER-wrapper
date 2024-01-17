clear all
clc

solar_eff = 1;
wind_eff =  1;

load('8_bus_600_gen_case.mat')
wind_gens = zeros(8,1);
wind_capacity = wind_gens;
solar_gens = zeros(8,1);
solar_capacity = solar_gens;
hydro_capacity = solar_capacity;
nuclear_capacity = hydro_capacity;
gas_capacity = hydro_capacity;
coal_capacity = gas_capacity;
cheap_capacity = solar_capacity;
exp_capacity = cheap_capacity;
free_capacity = cheap_capacity;
for i =1:length(mpc.genfuel)
    bus = mpc.gen(i,1);
    gen_type = string(mpc.genfuel(i));
    if gen_type == 'wind'
        wind_gens(bus) = wind_gens(bus) + 1;
        wind_capacity(bus) = wind_capacity(bus) + (wind_eff * mpc.gen(i,9)); 
    elseif gen_type == 'solar'
        solar_gens(bus) = solar_gens(bus) + 1;
        solar_capacity(bus) = solar_capacity(bus) + (solar_eff * mpc.gen(i,9));
    elseif gen_type == 'hydro'
        hydro_capacity(bus) = hydro_capacity(bus) + mpc.gen(i,9);
    elseif gen_type == 'nuclear'
        nuclear_capacity(bus) = nuclear_capacity(bus) + mpc.gen(i,9);
    elseif gen_type == 'ng'
        gas_capacity(bus) = gas_capacity(bus) + mpc.gen(i,9);
        exp_capacity(bus) = exp_capacity(bus) + mpc.gen(i,9);
    elseif gen_type == 'coal'
        coal_capacity(bus) = coal_capacity(bus) + mpc.gen(i,9);
        exp_capacity(bus) = exp_capacity(bus) + mpc.gen(i,9);
    else
        exp_capacity(bus) = exp_capacity(bus) + mpc.gen(i,9);
    end
end
cheap_capacity = wind_capacity + solar_capacity + hydro_capacity + nuclear_capacity;
fraction_cheap = sum(cheap_capacity) / (sum(exp_capacity+cheap_capacity))
free_capacity = wind_capacity + solar_capacity + hydro_capacity;
total_free = sum(free_capacity);
fraction_free = total_free / (sum(exp_capacity+cheap_capacity));
total_capacity = [cheap_capacity,exp_capacity];
stacked_capacity = [wind_capacity,solar_capacity,hydro_capacity,nuclear_capacity,gas_capacity,coal_capacity];

figure()
bar(total_capacity,'stacked')
hold on
title('Bus Capacity')
xlabel('bus')
ylabel('Capacity (MW)')
legend({'cheap(wind, solar, nuclear, hydro)','expensive(gas, coal)'})
hold off

figure()
bar(stacked_capacity,'stacked')
hold on
title('Bus Capacity')
xlabel('bus')
ylabel('Capacity (MW)')
legend({'wind','solar','hydro','nuclear','gas','coal'})
hold off
