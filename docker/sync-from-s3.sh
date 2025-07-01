#!/bin/bash
# Standalone S3 sync script for DAGs and workspace
# This script can be run independently or called from the main entrypoint

set -e

# Function to sync DAGs and workspace from S3
sync_from_s3() {
    echo "$(date): Starting S3 sync..."
    
    if [ -z "$DAGSTER_S3_BUCKET" ]; then
        echo "$(date): ERROR: DAGSTER_S3_BUCKET environment variable is required but not set!"
        return 1
    fi

    echo "$(date): Syncing from S3 bucket: $DAGSTER_S3_BUCKET"
    
    # Sync DAGs from S3 (with timeout and error handling)
    echo "$(date): Syncing DAGs..."
    if timeout 60 aws s3 sync "s3://$DAGSTER_S3_BUCKET/dags/" /app/dags/ --delete --exact-timestamps; then
        echo "$(date): DAG sync successful"
        DAG_COUNT=$(find /app/dags -name "*.py" -type f | wc -l)
        echo "$(date): Found $DAG_COUNT Python files in /app/dags/"
        
        # Ensure proper permissions
        chmod -R 755 /app/dags/
        
        return 0
    else
        echo "$(date): ERROR: DAG sync failed"
        return 1
    fi
    
    # Sync workspace.yaml from S3
    echo "$(date): Syncing workspace.yaml..."
    if timeout 30 aws s3 cp "s3://$DAGSTER_S3_BUCKET/workspace.yaml" /app/workspace.yaml --quiet; then
        echo "$(date): Workspace sync successful"
        WORKSPACE_SIZE=$(wc -c < /app/workspace.yaml)
        echo "$(date): Workspace file size: $WORKSPACE_SIZE bytes"
    else
        echo "$(date): WARNING: Workspace sync failed, keeping existing file"
    fi
    
    echo "$(date): S3 sync completed"
    return 0
}

# Main execution
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    # Script is being executed directly
    sync_from_s3
fi