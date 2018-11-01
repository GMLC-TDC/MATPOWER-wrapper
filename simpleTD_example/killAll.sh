#!/bin/bash

var=$(pgrep -o runAll.sh)
if [ -z "$var" ]
then
    echo "No processes are running"
else
    echo "Killing all processes of runAll.sh"
    kill -9 -$var >/dev/null
fi
