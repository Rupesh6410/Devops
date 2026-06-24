#!/bin/bash

SERVERS="192.168.0.101 192.168.0.102 192.168.0.103"

for server in $SERVERS
do
    echo "Checking $server..."
    ping -c 1 $server > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "$server is UP"
    else
        echo "$server is DOWN"
    fi
done

