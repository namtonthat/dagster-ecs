#!/bin/bash
# Multi-repository S3-based DAG management
# Syncs all DAGs from s3://bucket/dags/* to local container
set -e

echo "$(date): Starting Dagster with multi-repo DAG support..."

LOCAL_DAG_PATH="${DAGSTER_LOCAL_DAG_PATH:-/app/dags}"
SYNC_INTERVAL="${DAGSTER_SYNC_INTERVAL:-300}"  # 5 minutes default

# Function to sync all DAGs from S3
sync_all_dags_from_s3() {
    if [ -z "$DAGSTER_S3_BUCKET" ]; then
        echo "$(date): ERROR: DAGSTER_S3_BUCKET environment variable is required"
        return 1
    fi

    echo "$(date): Syncing all repository DAGs from S3..."
    echo "$(date): S3 Bucket: $DAGSTER_S3_BUCKET"
    echo "$(date): Local Path: $LOCAL_DAG_PATH"

    # Create local DAG directory
    mkdir -p "$LOCAL_DAG_PATH"

    # Sync all DAGs from s3://bucket/dags/* to /app/dags/
    if timeout 120 aws s3 sync "s3://$DAGSTER_S3_BUCKET/dags/" "$LOCAL_DAG_PATH/" --delete --exact-timestamps; then
        echo "$(date): Multi-repo DAG sync successful"
        
        # Set proper permissions
        chmod -R 755 "$LOCAL_DAG_PATH" 2>/dev/null || true
        
        # Count and list repositories
        REPO_COUNT=$(find "$LOCAL_DAG_PATH" -mindepth 1 -maxdepth 1 -type d | wc -l)
        DAG_COUNT=$(find "$LOCAL_DAG_PATH" -name "*.py" -type f | wc -l)
        
        echo "$(date): Found $REPO_COUNT repositories with $DAG_COUNT total Python files"
        
        # List repositories found
        if [ "$REPO_COUNT" -gt 0 ]; then
            echo "$(date): Repository directories:"
            find "$LOCAL_DAG_PATH" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort | sed 's/^/  - /'
        fi
        
        return 0
    else
        echo "$(date): ERROR: S3 sync failed"
        return 1
    fi
}

# Function for background sync (if enabled)
background_sync() {
    if [ "$SYNC_INTERVAL" -le 0 ]; then
        echo "$(date): Background sync disabled (DAGSTER_SYNC_INTERVAL <= 0)"
        return
    fi
    
    echo "$(date): Starting background sync every ${SYNC_INTERVAL} seconds..."
    while true; do
        sleep "$SYNC_INTERVAL"
        echo "$(date): Running background sync..."
        sync_all_dags_from_s3 || echo "$(date): Background sync failed, will retry in ${SYNC_INTERVAL} seconds"
    done
}

# Perform initial sync (critical for startup)
echo "$(date): Running initial DAG sync..."
if ! sync_all_dags_from_s3; then
    echo "$(date): CRITICAL: Initial DAG sync failed! Cannot start Dagster."
    echo "$(date): Check S3 bucket access and credentials."
    exit 1
fi

# Verify we have DAGs after sync
if [ ! -d "$LOCAL_DAG_PATH" ] || [ -z "$(find "$LOCAL_DAG_PATH" -name "*.py" -type f)" ]; then
    echo "$(date): WARNING: No Python DAG files found after sync!"
    echo "$(date): This may be expected if no repositories have deployed DAGs yet."
fi

# Start background sync process if enabled
if [ "$SYNC_INTERVAL" -gt 0 ]; then
    background_sync &
    echo "$(date): Background sync process started (PID: $!)"
fi

# Start the main Dagster process
echo "$(date): Starting Dagster process: $@"
exec "$@"