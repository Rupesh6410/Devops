#!/bin/bash

LOG_DIR="/var/log"
DAYS_OLD=7
echo "Cleaning log older than $DAYS_OLD days in $LOG_DIR"
find $LOG_DIR -name "*log" -mtime +$DAYS_OLD -type f | while read file
do
echo "Deleting :$file"
done

echo "cleanup complete"


