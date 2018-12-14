#!/bin/bash

clear

echo "Executing experiment..."

logFile="helics.out"
configFile="9bus_helics.json"
matpowerLogLevel="INFO"
experimentPath="/home/gkris756/mw_ccsiusecase/simpleTD_example"
export MATPOWER_LOG_LEVEL=$matpowerLogLevel

cd $experimentPath/matpower && start_MATPOWER $configFile case9.m real_power_demand.txt reactive_power_demand.txt renewable_power_generation.txt 86400 300 15 "2013-08-28 00:00:00" load_data.json generator_data.json &> $logFile &
cd $experimentPath/123-node && gridlabd IEEE_123_feeder_0.glm &> $logFile &
helics_broker 2 --log_level=3 &> $logFile &

echo "Waiting for processes to finish..."

wait

echo "Done..."  

exit 0