#!/bin/bash

echo "Enter your name:"
read USERNAME

echo "Enter the server IP to check:"
read SERVER_IP

echo "Checking connectivity for $USERNAME to $SERVER_IP..."
ping -c 2 $SERVER_IP
