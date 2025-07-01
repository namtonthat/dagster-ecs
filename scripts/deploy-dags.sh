#!/bin/bash
set -e

# Script to deploy DAGs to S3 bucket
# Usage: ./scripts/deploy-dags.sh [dag-directory]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Default DAG directory
DAG_DIR="${1:-$REPO_ROOT/dags}"

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

echo "🚀 Deploying DAGs to S3..."
echo "📁 DAG Directory: $DAG_DIR"
echo "🪣 S3 Bucket: $S3_BUCKET"

# Validate DAG directory exists
if [ ! -d "$DAG_DIR" ]; then
    echo "❌ Error: DAG directory '$DAG_DIR' does not exist."
    exit 1
fi

# Check if there are any Python files
PYTHON_FILES=$(find "$DAG_DIR" -name "*.py" -type f | wc -l)
if [ "$PYTHON_FILES" -eq 0 ]; then
    echo "⚠️  Warning: No Python files found in '$DAG_DIR'"
fi

# Sync DAGs to S3
echo "📤 Syncing DAGs to S3..."
aws s3 sync "$DAG_DIR" "s3://$S3_BUCKET/dags/" \
    --delete \
    --exclude "*.pyc" \
    --exclude "__pycache__/*" \
    --exclude ".DS_Store"

if [ $? -eq 0 ]; then
    echo "✅ Successfully deployed DAGs to S3!"
    echo "📋 Files uploaded:"
    aws s3 ls "s3://$S3_BUCKET/dags/" --recursive
    
    echo ""
    echo "🔄 To trigger DAG reload in ECS, run:"
    echo "   make deploy-ecs  # This will restart ECS service to pick up new DAGs"
else
    echo "❌ Failed to deploy DAGs to S3"
    exit 1
fi