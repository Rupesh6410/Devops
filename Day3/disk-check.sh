#!/bin/bash

THRESHOLD=80
USAGE=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')

echo "Current disk usage: $USAGE%"

if [ $USAGE -gt $THRESHOLD ]; then
    echo "WARNING: Disk usage is above threshold!"
else
    echo "Disk usage is normal."
fi

