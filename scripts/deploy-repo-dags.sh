#!/bin/bash
# Multi-repository DAG deployment script
# Usage: ./deploy-repo-dags.sh <repo-name> [dag-directory]
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Repository name (required)
REPO_NAME="${1}"
if [ -z "$REPO_NAME" ]; then
    echo "❌ Error: Repository name is required"
    echo "Usage: $0 <repo-name> [dag-directory]"
    echo ""
    echo "Examples:"
    echo "  $0 marketing-dags ./dags"
    echo "  $0 finance-pipelines ./src/pipelines"
    echo "  $0 data-science ."
    exit 1
fi

# DAG directory (optional, defaults to current directory)
DAG_DIR="${2:-.}"

# Validate repository name (alphanumeric, hyphens, underscores only)
if ! echo "$REPO_NAME" | grep -qE '^[a-zA-Z0-9_-]+$'; then
    echo "❌ Error: Repository name must contain only letters, numbers, hyphens, and underscores"
    exit 1
fi

# Get S3 bucket name
if [ -n "$DAGSTER_S3_BUCKET" ]; then
    S3_BUCKET="$DAGSTER_S3_BUCKET"
elif [ -f "$SCRIPT_DIR/../infrastructure/terraform.tfvars" ]; then
    # Try to get from infrastructure outputs if available
    cd "$SCRIPT_DIR/../infrastructure" 2>/dev/null
    S3_BUCKET=$(tofu output -raw s3_bucket_name 2>/dev/null || echo "")
    cd - >/dev/null
else
    S3_BUCKET=""
fi

if [ -z "$S3_BUCKET" ]; then
    echo "❌ Error: Could not determine S3 bucket name."
    echo "Please set DAGSTER_S3_BUCKET environment variable."
    echo ""
    echo "Example: export DAGSTER_S3_BUCKET=my-dagster-bucket"
    exit 1
fi

echo "🚀 Deploying DAGs for repository: $REPO_NAME"
echo "📁 DAG Directory: $DAG_DIR"
echo "🪣 S3 Bucket: $S3_BUCKET"
echo "📍 S3 Path: s3://$S3_BUCKET/dags/$REPO_NAME/"

# Validate DAG directory exists
if [ ! -d "$DAG_DIR" ]; then
    echo "❌ Error: DAG directory '$DAG_DIR' does not exist."
    exit 1
fi

# Check if there are any Python files
PYTHON_FILES=$(find "$DAG_DIR" -name "*.py" -type f | wc -l)
if [ "$PYTHON_FILES" -eq 0 ]; then
    echo "⚠️  Warning: No Python files found in '$DAG_DIR'"
    echo "Continuing anyway (might be cleaning up old DAGs)..."
fi

# Sync DAGs to repository-specific S3 path
echo "📤 Syncing DAGs to S3..."
aws s3 sync "$DAG_DIR" "s3://$S3_BUCKET/dags/$REPO_NAME/" \
    --delete \
    --exclude "*.pyc" \
    --exclude "__pycache__/*" \
    --exclude ".DS_Store" \
    --exclude ".git/*" \
    --exclude "*.md" \
    --exclude "*.txt"

if [ $? -eq 0 ]; then
    echo "✅ Successfully deployed DAGs for repository '$REPO_NAME'!"
    echo ""
    echo "📋 Repository DAGs:"
    aws s3 ls "s3://$S3_BUCKET/dags/$REPO_NAME/" --recursive
    echo ""
    echo "🔄 To trigger DAG reload in Dagster:"
    echo "   # Option 1: Manual restart (immediate)"
    echo "   aws ecs update-service --cluster <cluster-name> --service <service-name> --force-new-deployment"
    echo ""
    echo "   # Option 2: Wait for automatic sync (up to 5 minutes)"
    echo "   # Containers automatically sync every 5 minutes"
    echo ""
    echo "🌐 View your DAGs at: <dagster-url>"
else
    echo "❌ Failed to deploy DAGs for repository '$REPO_NAME'"
    exit 1
fi