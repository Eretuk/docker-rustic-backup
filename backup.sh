#!/bin/bash
# backup.sh: The pure executor script called by cron.

# Exit immediately if a command exits with a non-zero status.
set -e 

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

echo "$(date): --> Checking repository availability..."
# Check for repository errors. If an error is found, initialize it.
if rustic check --json 2>&1 | grep -q 'error'; then
    echo "$(date): Repository not found or seems damaged. Attempting to initialize..."
    rustic init
fi

# ----------------------------------------------------
# 3. RUN THE BACKUP (Backup)
# ----------------------------------------------------

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
# 4. CLEANUP OLD SNAPSHOTS (Prune/Forget)
# ----------------------------------------------------

echo "$(date): --> Starting cleanup (prune/forget) with policy: ${PRUNE_POLICY}"
rustic prune --forget ${PRUNE_POLICY}

# ----------------------------------------------------
# 5. VERIFY INTEGRITY (Check)
# ----------------------------------------------------

# Note: Check is kept for completeness, but can be disabled or scheduled separately
# to reduce daily resource usage.
echo "$(date): --> Running integrity check (check)..."
rustic check

echo "$(date): --- ALL BACKUP TASKS COMPLETED SUCCESSFULLY. ---"