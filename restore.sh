#!/bin/bash
# restore.sh: Interactive script to restore a snapshot.

# Exit immediately if a command exits with a non-zero status.
set -e

echo "--- Rustic Interactive Restore ---"

# --- 1. Filter by Host ---
read -p "Enter hostname to filter snapshots (or leave blank for all): " HOST_FILTER

echo "Fetching available snapshots..."

# --- 2. Display Snapshots ---
if [ -n "$HOST_FILTER" ]; then
    echo "Displaying snapshots for host: ${HOST_FILTER}"
    rustic snapshots --host "${HOST_FILTER}"
else
    echo "Displaying all snapshots..."
    rustic snapshots
fi

echo "----------------------------------"
# --- 3. Select Snapshot ---
read -p "Please enter the full ID of the snapshot you want to restore: " SNAPSHOT_ID

# Exit if the user didn't provide an ID
if [ -z "$SNAPSHOT_ID" ]; then
    echo "No snapshot ID entered. Aborting."
    exit 1
fi

# --- 4. Select Destination ---
read -p "Enter the absolute path inside the container to restore to [default: /restore]: " RESTORE_PATH

# Use default value if user input is empty
RESTORE_PATH=${RESTORE_PATH:-/restore}

echo "--- Summary ---"
echo "Snapshot to restore: ${SNAPSHOT_ID}"
echo "Restore destination: ${RESTORE_PATH}"
echo "-----------------"

# --- 5. Confirm and Restore ---
read -p "Are you sure you want to proceed? (y/N): " CONFIRMATION
if [[ ! "$CONFIRMATION" =~ ^[yY](es)?$ ]]; then
    echo "Restore cancelled."
    exit 0
fi

# Create the target directory if it doesn't exist
mkdir -p "${RESTORE_PATH}"

echo "Starting restore process..."
# Execute the restore command
rustic restore "${SNAPSHOT_ID}" "${RESTORE_PATH}"

echo "----------------------------------"
echo "✅ Restore completed successfully!"
echo "Your files are available in the container at: ${RESTORE_PATH}"
echo "Check the volume mounts on your host to access them."