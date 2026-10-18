#!/bin/bash
# script.sh - Resource monitor
# Every INTERVAL seconds appends free -h, df -h, uptime to monitor.log.

LOG_FILE="monitor.log"
INTERVAL=5

touch "$LOG_FILE"

trap 'echo "Monitoring stopped."; exit 0' INT

echo "Monitoring every ${INTERVAL}s. Log: $LOG_FILE. Press Ctrl+C to stop."

while true; do
    {
        echo "--- $(date '+%Y-%m-%d %H:%M:%S') ---"
        free -h
        df -h
        uptime
        echo ""
    } >> "$LOG_FILE"
    sleep "$INTERVAL"
done
