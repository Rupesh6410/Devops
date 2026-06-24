#!/bin/bash

check_service() {
    SERVICE_NAME=$1
    sudo systemctl is-active --quiet $SERVICE_NAME
    if [ $? -eq 0 ]; then
        echo "$SERVICE_NAME is running"
    else
        echo "$SERVICE_NAME is NOT running"
    fi
}

check_service nginx
check_service cron

THRESHOLD=80
USAGE=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')

echo "Current disk usage: $USAGE%"

if [ $USAGE -gt $THRESHOLD ]; then
    echo "WARNING: Disk usage is above threshold!"
else
    echo "Disk usage is normal."
fi
