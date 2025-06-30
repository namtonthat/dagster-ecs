#!/bin/bash
set -e

# Script to deploy workspace.yaml to S3 bucket
# Usage: ./scripts/deploy-workspace.sh [workspace-file]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Default workspace file
WORKSPACE_FILE="${1:-$REPO_ROOT/workspace.yaml}"

# Get S3 bucket name from terraform outputs
if [ -d "$REPO_ROOT/infrastructure" ]; then
    cd "$REPO_ROOT/infrastructure"
    S3_BUCKET=$(tofu output -raw s3_bucket_name 2>/dev/null || echo "")
    cd "$REPO_ROOT"
else
    S3_BUCKET=""
fi

# Fallback: try to get from environment or prompt user
if [ -z "$S3_BUCKET" ]; then
    if [ -n "$DAGSTER_S3_BUCKET" ]; then
        S3_BUCKET="$DAGSTER_S3_BUCKET"
    else
        echo "Error: Could not determine S3 bucket name."
        echo "Please set DAGSTER_S3_BUCKET environment variable or ensure infrastructure is deployed."
        echo ""
        echo "To get the bucket name from deployed infrastructure:"
        echo "  cd infrastructure && tofu output s3_bucket_name"
        exit 1
    fi
fi

echo "🚀 Deploying workspace.yaml to S3..."
echo "📁 Workspace File: $WORKSPACE_FILE"
echo "🪣 S3 Bucket: $S3_BUCKET"

# Validate workspace file exists
if [ ! -f "$WORKSPACE_FILE" ]; then
    echo "❌ Error: Workspace file '$WORKSPACE_FILE' does not exist."
    exit 1
fi

# Upload workspace.yaml to S3
echo "📤 Uploading workspace.yaml to S3..."
aws s3 cp "$WORKSPACE_FILE" "s3://$S3_BUCKET/workspace.yaml"

if [ $? -eq 0 ]; then
    echo "✅ Successfully deployed workspace.yaml to S3!"
    echo "📋 File details:"
    aws s3 ls "s3://$S3_BUCKET/workspace.yaml"
    
    echo ""
    echo "🔄 To apply changes in ECS, run:"
    echo "   make deploy  # This will restart ECS service to pick up new workspace"
else
    echo "❌ Failed to deploy workspace.yaml to S3"
    exit 1
fi