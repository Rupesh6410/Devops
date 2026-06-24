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
check_service ssh
