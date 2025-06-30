#!/bin/bash
set -e

# Redirect all output to both stdout and CloudWatch logs
exec > >(tee -a /proc/1/fd/1)
exec 2> >(tee -a /proc/1/fd/2)

echo "========================================="
echo "Starting Dagster container entrypoint..."
echo "========================================="

# Debug information
echo "Current user: $(whoami)"
echo "Current directory: $(pwd)"
echo "Environment variables:"
env | grep -E "(AWS|DAGSTER)" || echo "No AWS/DAGSTER environment variables found"

# Function to setup basic auth credentials
setup_auth() {
    echo "Setting up basic authentication..."
    
    # Default credentials if not provided via environment
    DAGSTER_AUTH_USER="${DAGSTER_AUTH_USER:-admin}"
    DAGSTER_AUTH_PASSWORD="${DAGSTER_AUTH_PASSWORD:-DagsterPipeline2024!}"
    
    # Generate .htpasswd file
    echo "$DAGSTER_AUTH_USER:$(openssl passwd -apr1 "$DAGSTER_AUTH_PASSWORD")" > /etc/nginx/.htpasswd
    
    echo "Basic auth configured for user: $DAGSTER_AUTH_USER"
    echo "WARNING: Using default credentials! Set DAGSTER_AUTH_USER and DAGSTER_AUTH_PASSWORD environment variables for security."
}

# Function to sync DAGs and workspace from S3
sync_from_s3() {
    echo "Starting S3 sync function..."
    
    if [ -z "$DAGSTER_S3_BUCKET" ]; then
        echo "ERROR: DAGSTER_S3_BUCKET environment variable is required but not set!"
        exit 1
    fi

    echo "Syncing DAGs and workspace from S3 bucket: $DAGSTER_S3_BUCKET"
    
    # Create directories if they don't exist
    echo "Creating /app/dags directory..."
    mkdir -p /app/dags
    ls -la /app/
    
    # Test AWS credentials
    echo "Testing AWS credentials..."
    aws sts get-caller-identity || echo "AWS credentials test failed"
    
    # Test S3 bucket access
    echo "Testing S3 bucket access..."
    aws s3 ls "s3://$DAGSTER_S3_BUCKET/" || echo "S3 bucket access test failed"
    
    # Sync DAGs from S3 to local filesystem (from dags/ prefix in S3)
    echo "Running S3 DAGs sync command..."
    # The --delete flag removes files that are no longer in S3
    timeout 30 aws s3 sync "s3://$DAGSTER_S3_BUCKET/dags/" /app/dags/ --delete --exact-timestamps
    DAGS_SYNC_EXIT_CODE=$?
    
    # Sync workspace.yaml from S3 to local filesystem
    echo "Running S3 workspace sync command..."
    timeout 30 aws s3 cp "s3://$DAGSTER_S3_BUCKET/workspace.yaml" /app/workspace.yaml || echo "Workspace file not found in S3, using local fallback"
    WORKSPACE_SYNC_EXIT_CODE=$?
    
    if [ $DAGS_SYNC_EXIT_CODE -eq 0 ]; then
        echo "Successfully synced DAGs from S3"
        echo "DAG files found:"
        find /app/dags -name "*.py" -type f | head -10
        echo "Directory contents:"
        ls -la /app/dags/
        echo "Last sync: $(date)"
    else
        echo "ERROR: Failed to sync DAGs from S3 (exit code: $DAGS_SYNC_EXIT_CODE)"
        return 1
    fi
    
    # Check workspace file status
    if [ -f "/app/workspace.yaml" ]; then
        echo "Workspace file successfully available at /app/workspace.yaml"
        echo "Workspace file size: $(wc -c < /app/workspace.yaml) bytes"
    else
        echo "WARNING: No workspace.yaml file found, Dagster may fail to start"
        return 1
    fi
    
    return 0
}

# Function to run periodic sync in background
periodic_sync() {
    echo "$(date): Starting periodic sync daemon..."
    
    # Wait for initial startup to complete
    sleep 30
    
    while true; do
        echo "$(date): Performing periodic DAG and workspace sync..."
        
        # Use the dedicated sync script
        if ./sync-from-s3.sh; then
            echo "$(date): Periodic sync completed successfully"
        else
            echo "$(date): Periodic sync failed, will retry in 10 minutes"
        fi
        
        # Sleep for 10 minutes (600 seconds)
        echo "$(date): Next sync in 10 minutes..."
        sleep 600
    done
}

# Setup authentication
setup_auth

# Check if running in local development mode
if [ "$AWS_ACCESS_KEY_ID" = "local" ] || [ "$AWS_SECRET_ACCESS_KEY" = "local" ]; then
    echo "Detected local development mode, skipping S3 sync..."
    SYNC_PID=""
else
    # Initial sync - this must succeed for container to start
    echo "$(date): Running initial S3 sync..."
    sync_from_s3
    
    # Start periodic sync in background as a daemon
    echo "$(date): Starting periodic sync daemon..."
    periodic_sync &
    SYNC_PID=$!
    echo "$(date): Periodic sync daemon started with PID: $SYNC_PID"
fi

# Fix permissions for dagster home directory
if [ "$(id -u)" = '0' ]; then
    # Running as root, fix permissions
    chown -R root:root /app/.dagster_home /app/dags 2>/dev/null || true
fi

# Cleanup function
cleanup() {
    if [ -n "$SYNC_PID" ]; then
        echo "Shutting down periodic sync..."
        kill $SYNC_PID 2>/dev/null || true
    fi
    exit 0
}

# Set up signal handlers
trap cleanup SIGTERM SIGINT

# Execute the original command
echo "Starting Dagster with command: $@"
exec "$@"