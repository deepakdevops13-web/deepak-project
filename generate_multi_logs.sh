#!/bin/bash
# ---------------------------------------------------------------------
# Multi-log generator for Promtail/Loki testing
# Continuously writes random INFO, WARNING, and ERROR logs
# into multiple log files under /var/log/apache2/
# ---------------------------------------------------------------------

LOG_DIR="/var/log/titan"
APPS=("app1" "app2" "app3")   # log files will be app1.log, app2.log, app3.log
INTERVAL_MIN=1                 # minimum seconds between logs per app
INTERVAL_MAX=3                 # maximum seconds between logs per app

# Ensure directory and log files exist
sudo mkdir -p "$LOG_DIR"
for app in "${APPS[@]}"; do
  sudo touch "$LOG_DIR/${app}.log"
  sudo chmod 644 "$LOG_DIR/${app}.log"
done

echo "[$(date)] Starting multi-log generation in $LOG_DIR ..."
sleep 2

# Function to generate logs for one app
generate_logs() {
  local APP_NAME=$1
  local LOG_FILE="$LOG_DIR/${APP_NAME}.log"

  while true; do
    # Random log level
    LEVELS=("INFO" "WARNING" "ERROR")
    LEVEL=${LEVELS[$((RANDOM % ${#LEVELS[@]}))]}

    # Random log message
    case $LEVEL in
      "INFO")
        MSGS=("Request served successfully"
              "User logged in"
              "Health check passed"
              "Cache refreshed"
              "Configuration reloaded"
              "New connection established")
        ;;
      "WARNING")
        MSGS=("High memory usage"
              "Slow response time"
              "Disk space low"
              "Deprecated API call"
              "Authentication delay detected"
              "Network latency increased")
        ;;
      "ERROR")
        MSGS=("Database connection failed"
              "File not found"
              "Service timeout"
              "Permission denied"
              "Failed to load configuration"
              "Application crashed unexpectedly")
        ;;
    esac
    MESSAGE=${MSGS[$((RANDOM % ${#MSGS[@]}))]}

    # Add random client IP
    IP="192.168.$((RANDOM % 256)).$((RANDOM % 256))"

    # Apache-style timestamp
    TIMESTAMP=$(date "+%d/%b/%Y:%H:%M:%S %z")

    # Write formatted log entry
    echo "$IP - - [$TIMESTAMP] \"$LEVEL [$APP_NAME]: $MESSAGE\"" >> "$LOG_FILE"

    # Sleep for a random interval
    SLEEP_TIME=$((RANDOM % (INTERVAL_MAX - INTERVAL_MIN + 1) + INTERVAL_MIN))
    sleep $SLEEP_TIME
  done
}

# Launch a background process for each app
for app in "${APPS[@]}"; do
  generate_logs "$app" &
done

# Wait for all to complete (they never will)
wait

