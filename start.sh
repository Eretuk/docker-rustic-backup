#!/bin/bash
# start.sh: Initializes the cron schedule and starts the daemon.

# Exit immediately if any command fails
set -e

# --- 1. Validate Schedule Variable ---
# Ensure the required CRON_SCHEDULE variable is set by the user
if [ -z "$CRON_SCHEDULE" ]; then
    echo "ERROR: CRON_SCHEDULE environment variable is not set."
    echo "Please set it (e.g., '0 3 * * *' for 3 AM daily)."
    exit 1
fi

# --- 2. Create Dynamic Crontab ---
# Create the crontab file based on the user-defined schedule.
# The job calls the backup executor script. Logs are redirected to cron.log.
CRONTAB_FILE="/var/spool/cron/crontabs/root"
echo "Creating crontab entry: ${CRON_SCHEDULE} /usr/local/bin/backup.sh"

# Note: The absolute path to the script is required by cron.
echo "${CRON_SCHEDULE} /usr/local/bin/backup.sh" > ${CRONTAB_FILE}

# Ensure the crontab file has the correct permissions (not strictly needed for root, but good practice)
chmod 600 ${CRONTAB_FILE}

# --- 3. Start Daemon ---
echo "Starting cron daemon in foreground..."
exec /usr/sbin/cron -f -L 8
echo "Cron daemon is running. Container is now in daemon mode."