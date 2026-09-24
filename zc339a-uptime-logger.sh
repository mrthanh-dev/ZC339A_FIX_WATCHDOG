#!/bin/sh
# Log system uptime every 60 seconds with flush to disk
LOGFILE="/home/orangepi/uptime.txt"

while true; do
    echo "$(date '+%Y-%m-%d %H:%M:%S') | $(uptime)" >> "$LOGFILE"
    sync
    sleep 60
done
