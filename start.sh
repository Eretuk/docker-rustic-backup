#!/bin/bash
# start.sh: Initializes the cron schedule and starts the daemon.

# Exit immediately if any command fails
set -e

# --- 0. Determine Container Role ---
# Default to "backup" role if not specified
CONTAINER_ROLE=${CONTAINER_ROLE:-"backup"}

# --- 1. Validate Core Variables ---
if [ -z "$CRON_SCHEDULE" ]; then
    echo "ERROR: CRON_SCHEDULE environment variable is not set."
    exit 1
fi

if [ -z "$RUSTIC_PASSWORD" ]; then
    echo "ERROR: RUSTIC_PASSWORD environment variable is not set."
    exit 1
fi

# --- 2. S3 Configuration & Bucket Check ---
# Check for S3 variables. If they exist, configure rustic and check the bucket.
if [ -n "$S3_ENDPOINT" ] && [ -n "$S3_BUCKET" ] && [ -n "$AWS_ACCESS_KEY_ID" ] && [ -n "$AWS_SECRET_ACCESS_KEY" ]; then
    echo "S3 environment variables detected. Configuring rustic and checking bucket..."

    # Sanitize S3 variables by removing quotes that might come from docker-compose/.env files
    S3_ENDPOINT=${S3_ENDPOINT//\"/}
    S3_BUCKET=${S3_BUCKET//\"/}
    # Set a default region if not provided
    S3_REGION=${S3_REGION:-"us-east-1"}

    # --- Create rustic config file ---
    mkdir -p /etc/rustic
    cat <<EOF > /etc/rustic/rustic.toml
[repository]
repository = "opendal:s3"
password = "${RUSTIC_PASSWORD}"

[repository.options]
endpoint = "${S3_ENDPOINT}"
bucket = "${S3_BUCKET}"
region = "${S3_REGION}"
access_key_id = "${AWS_ACCESS_KEY_ID}"
secret_access_key = "${AWS_SECRET_ACCESS_KEY}"
EOF
    echo "Rustic config created at /etc/rustic/rustic.toml"

    # --- Check and Create S3 Bucket ---
    echo "Configuring MinIO client for endpoint: ${S3_ENDPOINT}"
    mc alias set s3_storage "${S3_ENDPOINT}" "${AWS_ACCESS_KEY_ID}" "${AWS_SECRET_ACCESS_KEY}" --api S3v4

    if mc ls "s3_storage/${S3_BUCKET}" > /dev/null 2>&1; then
        echo "Bucket '${S3_BUCKET}' already exists."
    else
        echo "Bucket '${S3_BUCKET}' not found. Creating it..."
        mc mb "s3_storage/${S3_BUCKET}"
        echo "Bucket '${S3_BUCKET}' created successfully."
    fi
else
    echo "WARNING: S3 environment variables (S3_ENDPOINT, S3_BUCKET, AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY) are not fully set."
    echo "Skipping S3 configuration and bucket creation. Rustic might fail if not configured otherwise."
fi


# --- 3. Role-based Execution ---
if [ "$CONTAINER_ROLE" = "backup" ]; then
    echo "--- Starting in Backup Mode ---"
    if [ -z "$CRON_SCHEDULE" ]; then
        echo "ERROR: CRON_SCHEDULE environment variable is not set for backup mode."
        exit 1
    fi
    # Create Dynamic Crontab
    CRONTAB_FILE="/var/spool/cron/crontabs/root"
    echo "Creating crontab entry: ${CRON_SCHEDULE} /usr/local/bin/backup.sh"
    echo "${CRON_SCHEDULE} /usr/local/bin/backup.sh" > ${CRONTAB_FILE}
    chmod 600 ${CRONTAB_FILE}

    # Start Cron Daemon
    echo "Starting cron daemon in foreground..."
    exec /usr/sbin/cron -f -L 8

elif [ "$CONTAINER_ROLE" = "restore" ]; then
    echo "--- Starting in Restore Mode ---"
    echo "The container is now running and ready for restore operations."
    echo "To restore a backup, run the following command:"
    echo "  docker exec -it ${HOSTNAME} /usr/local/bin/restore.sh"
    echo "--------------------------------------------------------"
    # Keep container alive
    exec tail -f /dev/null

else
    echo "ERROR: Invalid CONTAINER_ROLE specified: '${CONTAINER_ROLE}'. Use 'backup' or 'restore'."
    exit 1
fi