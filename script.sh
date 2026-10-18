#!/bin/bash
# script.sh - Resource monitor
# Every INTERVAL seconds appends free -h, df -h, uptime to monitor.log

LOG_FILE="monitor.log"
INTERVAL=5

while true; do
    echo "--- $(date '+%Y-%m-%d %H:%M:%S') ---" >> "$LOG_FILE"
    free -h >> "$LOG_FILE"
    df -h >> "$LOG_FILE"
    uptime >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
    sleep "$INTERVAL"
done

