#!/bin/bash
# prune.sh: Run repository maintenance (forget, prune, check) — intended for CONTAINER_ROLE=prune

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

trap 'send_notification "failure" "Prune script failed at line $LINENO. Check container logs for details."' ERR

# Optional random delay to avoid collisions with other scheduled jobs
if [ -n "$RANDOM_DELAY_SECONDS" ] && [ "$RANDOM_DELAY_SECONDS" -gt 0 ]; then
    DELAY=${RANDOM_DELAY_SECONDS//\"/}
    SLEEP_TIME=$((RANDOM % DELAY))
    echo "$(date): Starting random delay of ${SLEEP_TIME}s (max ${DELAY}s)..."
    sleep ${SLEEP_TIME}
fi

PRUNE_POLICY=${PRUNE_POLICY:-"--keep-last 3 --keep-daily 7 --keep-weekly 4 --keep-monthly 12"}
CHECK_ARGS=${CHECK_ARGS:-"--read-data --read-data-subset 10%"}

echo "$(date): --> Ensuring repository is initialized..."
if ! rustic cat config > /dev/null 2>&1; then
    echo "$(date): Repository not initialized. Attempting to initialize..."
    rustic init
fi

echo "$(date): --> Applying retention policy (forget) with policy: ${PRUNE_POLICY}"
rustic forget ${PRUNE_POLICY}

echo "$(date): --> Pruning unreferenced data from repository..."
rustic prune

echo "$(date): --> Running integrity check (check)..."
rustic check ${CHECK_ARGS}

echo "$(date): --- MAINTENANCE COMPLETED SUCCESSFULLY. ---"
send_notification "success" "Rustic maintenance (forget/prune/check) completed successfully."