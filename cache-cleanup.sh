#!/bin/bash
# cache-cleanup.sh: Clean up old cache files to free disk space.

set -e

send_notification() {
    local status=$1
    local message=$2

    if [ -n "$N8N_WEBHOOK_URL" ]; then
        curl -X POST -H "Content-Type: application/json" \
            -d "{\"hostname\": \"${HOSTNAME}\", \"status\": \"${status}\", \"message\": \"${message}\"}" \
            "${N8N_WEBHOOK_URL}" --silent --output /dev/null || echo "$(date): WARNING: Failed to send notification to n8n."
    fi
}

trap 'send_notification "failure" "Cache cleanup script failed at line $LINENO. Check container logs for details."' ERR

# --- Configuration ---
CACHE_DIR="/root/.cache/rustic"
CLEANUP_DAYS=${CACHE_CLEANUP_DAYS:-7}

echo "$(date): --> Starting cache cleanup process..."
echo "$(date): Cache directory: ${CACHE_DIR}"
echo "$(date): Removing files not accessed for more than ${CLEANUP_DAYS} day(s)..."

# Check if cache directory exists
if [ ! -d "${CACHE_DIR}" ]; then
    echo "$(date): Cache directory does not exist. Skipping cleanup."
    exit 0
fi

# Get initial size
INITIAL_SIZE=$(du -sh "${CACHE_DIR}" 2>/dev/null | cut -f1)
echo "$(date): Initial cache size: ${INITIAL_SIZE}"

# Find and delete files not accessed for more than CLEANUP_DAYS
# Using -atime (access time) based on the user's successful command
DELETED_COUNT=$(find "${CACHE_DIR}" -type f -atime +${CLEANUP_DAYS} -delete -print | wc -l)

# Get final size
FINAL_SIZE=$(du -sh "${CACHE_DIR}" 2>/dev/null | cut -f1 || echo "0K")
echo "$(date): Final cache size: ${FINAL_SIZE}"
echo "$(date): Deleted ${DELETED_COUNT} old cache file(s)."

if [ ${DELETED_COUNT} -gt 0 ]; then
    CLEANUP_MESSAGE="Cache cleanup completed. Removed ${DELETED_COUNT} file(s). Final cache size: ${FINAL_SIZE}"
    echo "$(date): ${CLEANUP_MESSAGE}"
    send_notification "success" "${CLEANUP_MESSAGE}"
else
    echo "$(date): No old cache files found to delete."
fi
