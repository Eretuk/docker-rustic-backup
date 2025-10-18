#!/bin/bash
# backup.sh: The pure executor script called by cron.

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Notification & Error Handling ---
# Generic function to send a notification to the webhook URL.
# It accepts two arguments: status ("success" or "failure") and a message.
send_notification() {
    local status=$1
    local message=$2

    if [ -n "$N8N_WEBHOOK_URL" ]; then
        echo "$(date): --> Sending ${status} notification to n8n..."
        # Send a POST request with a dynamic JSON payload
        curl -X POST \
             -H "Content-Type: application/json" \
             -d "{\"hostname\": \"${HOSTNAME}\", \"status\": \"${status}\", \"message\": \"${message}\"}" \
             "${N8N_WEBHOOK_URL}" \
             --silent --output /dev/null || echo "$(date): WARNING: Failed to send notification to n8n."
    fi
}

# Set the trap: if any command fails (ERR), call the notification function with a failure status.
trap 'send_notification "failure" "Backup script failed at line $LINENO. Check container logs for details."' ERR

# --- Optional Random Delay ---
# If RANDOM_DELAY_SECONDS is set, sleep for a random duration up to its value
# to prevent a "thundering herd" of backups from multiple hosts.
if [ -n "$RANDOM_DELAY_SECONDS" ] && [ "$RANDOM_DELAY_SECONDS" -gt 0 ]; then
    # Sanitize the variable to ensure it's a number
    DELAY=${RANDOM_DELAY_SECONDS//\"/}
    SLEEP_TIME=$((RANDOM % DELAY))
    echo "$(date): Starting random delay of ${SLEEP_TIME}s (max ${DELAY}s)..."
    sleep ${SLEEP_TIME}
fi

# ----------------------------------------------------
# 1. VALIDATION (Ensure Executor Variables Are Set)
# ----------------------------------------------------
# Validate required variables (though RUSTIC_REPOSITORY/PASSWORD are implicitly checked by Rustic)
if [ -z "$BACKUP_PATHS" ]; then
    echo "ERROR: BACKUP_PATHS environment variable is not set. Exiting executor."
    exit 1
fi

# PRUNE_POLICY is optional, default if not set
PRUNE_POLICY=${PRUNE_POLICY:-"--keep-daily 7 --keep-weekly 4 --keep-monthly 12"}

# ----------------------------------------------------
# 2. INITIALIZATION (Check and Initialize Repository)
# ----------------------------------------------------

echo "$(date): --> Checking if repository is initialized..."
# A more reliable way to check for an initialized repo is to try reading its config.
# If this command fails, the repository does not exist yet and must be initialized.
if ! rustic cat config > /dev/null 2>&1; then
    echo "$(date): Repository not initialized. Attempting to initialize..."
    rustic init
fi

# ----------------------------------------------------
# 3. RUN THE BACKUP (Backup)
# ----------------------------------------------------

# Validate that backup paths exist before running the backup
for path in $BACKUP_PATHS; do
    if [ ! -e "$path" ]; then
        echo "$(date): !!! ERROR: Backup source path does not exist: $path !!!"
        echo "$(date): Please check your volume mounts and the BACKUP_PATHS variable."
        exit 1
    fi
done

echo "$(date): --> Starting backup process for paths: ${BACKUP_PATHS}"
rustic backup ${BACKUP_PATHS}
STATUS=$?

if [ $STATUS -ne 0 ]; then
    echo "$(date): !!! BACKUP FAILED (exit code $STATUS) !!!"
    # Optional: Add external notification logic here
    exit 1
fi
echo "$(date): Backup successfully completed."

# ----------------------------------------------------
# 4. CLEANUP OLD SNAPSHOTS (Forget & Prune)
# ----------------------------------------------------

echo "$(date): --> Applying retention policy (forget) with policy: ${PRUNE_POLICY}"
rustic forget ${PRUNE_POLICY}

echo "$(date): --> Pruning unreferenced data from repository..."
rustic prune

# ----------------------------------------------------
# 5. VERIFY INTEGRITY (Check)
# ----------------------------------------------------

# Note: Check is kept for completeness, but can be disabled or scheduled separately
# to reduce daily resource usage.
echo "$(date): --> Running integrity check (check)..."
rustic check ${CHECK_ARGS}

echo "$(date): --- ALL BACKUP TASKS COMPLETED SUCCESSFULLY. ---"

# ----------------------------------------------------
# 6. SEND SUCCESS NOTIFICATION
# ----------------------------------------------------
# The trap above handles failures, so if we reach this point, the backup was successful.
send_notification "success" "Rustic backup completed successfully."