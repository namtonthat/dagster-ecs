#!/bin/bash
set -e

# Script to deploy a Dagster project to EFS and trigger refresh
# Usage: ./scripts/deploy-project.sh <project-name> <project-path> [--register]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Arguments
PROJECT_NAME="${1}"
PROJECT_PATH="${2}"
REGISTER_FLAG="${3}"

# Validate arguments
if [ -z "$PROJECT_NAME" ] || [ -z "$PROJECT_PATH" ]; then
    echo "Usage: $0 <project-name> <project-path> [--register]"
    echo ""
    echo "Arguments:"
    echo "  project-name   Unique identifier for the project (e.g., team-marketing)"
    echo "  project-path   Path to the project directory containing pyproject.toml"
    echo "  --register     Also register the project in workspace.yaml"
    exit 1
fi

# Validate project directory
if [ ! -d "$PROJECT_PATH" ]; then
    echo "❌ Error: Project directory '$PROJECT_PATH' does not exist"
    exit 1
fi

if [ ! -f "$PROJECT_PATH/pyproject.toml" ] && [ ! -f "$PROJECT_PATH/setup.py" ]; then
    echo "❌ Error: No pyproject.toml or setup.py found in '$PROJECT_PATH'"
    echo "This doesn't appear to be a valid Python project"
    exit 1
fi

# Get EFS mount ID from terraform outputs
get_efs_mount() {
    if [ -d "$REPO_ROOT/infrastructure" ]; then
        cd "$REPO_ROOT/infrastructure"
        EFS_ID=$(tofu output -raw efs_file_system_id 2>/dev/null || echo "")
        cd "$REPO_ROOT"
    else
        EFS_ID=""
    fi
    
    if [ -z "$EFS_ID" ]; then
        echo "❌ Error: Could not determine EFS file system ID"
        echo "Ensure infrastructure is deployed: make infra-apply"
        exit 1
    fi
    
    echo "$EFS_ID"
}

# Mount EFS locally for deployment
mount_efs() {
    local efs_id="$1"
    local mount_point="/mnt/dagster-efs"
    
    echo "🔗 Mounting EFS ($efs_id) to $mount_point..."
    
    # Create mount point
    sudo mkdir -p "$mount_point"
    
    # Install EFS utilities if not present
    if ! command -v mount.efs &> /dev/null; then
        echo "📦 Installing EFS mount utilities..."
        sudo apt-get update && sudo apt-get install -y amazon-efs-utils || \
        sudo yum install -y amazon-efs-utils
    fi
    
    # Get availability zone for mount
    AZ=$(aws ec2 describe-availability-zones --query 'AvailabilityZones[0].ZoneName' --output text)
    
    # Mount EFS
    sudo mount -t efs -o tls "$efs_id:/" "$mount_point" || {
        echo "❌ Failed to mount EFS. Trying with DNS name..."
        DNS_NAME="$efs_id.efs.$AWS_DEFAULT_REGION.amazonaws.com"
        sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport "$DNS_NAME:/" "$mount_point"
    }
    
    echo "✅ EFS mounted successfully"
    echo "$mount_point"
}

# Deploy project to EFS
deploy_to_efs() {
    local project_name="$1"
    local project_path="$2"
    local efs_mount="$3"
    
    local target_path="$efs_mount/projects/$project_name"
    
    echo "📤 Deploying project '$project_name' to EFS..."
    echo "   Source: $project_path"
    echo "   Target: $target_path"
    
    # Create target directory
    sudo mkdir -p "$target_path"
    
    # Sync project files
    sudo rsync -av --delete \
        --exclude='__pycache__' \
        --exclude='*.pyc' \
        --exclude='.git' \
        --exclude='.venv' \
        --exclude='venv' \
        --exclude='.pytest_cache' \
        --exclude='.tox' \
        --exclude='*.egg-info' \
        --exclude='.DS_Store' \
        "$project_path/" "$target_path/"
    
    # Set permissions
    sudo chmod -R 755 "$target_path"
    
    echo "✅ Project deployed successfully"
}

# Register project in workspace.yaml
register_project() {
    local project_name="$1"
    local efs_mount="$2"
    local workspace_file="$efs_mount/config/workspace.yaml"
    
    echo "📝 Registering project in workspace.yaml..."
    
    # Ensure config directory exists
    sudo mkdir -p "$(dirname "$workspace_file")"
    
    # Create workspace.yaml if it doesn't exist
    if [ ! -f "$workspace_file" ]; then
        echo "Creating new workspace.yaml..."
        sudo tee "$workspace_file" > /dev/null << 'EOF'
# Dagster workspace configuration
# Automatically updated when new projects are deployed
load_from: []
EOF
    fi
    
    # Check if project is already registered
    if grep -q "working_directory: /app/projects/$project_name" "$workspace_file" 2>/dev/null; then
        echo "ℹ️  Project '$project_name' is already registered"
        return 0
    fi
    
    # Create temporary file with updated configuration
    local temp_file="/tmp/workspace_update_$$.yaml"
    
    # Read current config and add new project
    python3 << EOF > "$temp_file"
import yaml
import sys

# Read current workspace
with open('$workspace_file', 'r') as f:
    workspace = yaml.safe_load(f) or {}

# Ensure load_from is a list
if 'load_from' not in workspace:
    workspace['load_from'] = []
elif not isinstance(workspace['load_from'], list):
    workspace['load_from'] = []

# Add new project entry
new_entry = {
    'python_module': {
        'module_name': '${project_name//-/_}.definitions',
        'working_directory': '/app/projects/$project_name'
    }
}

# Check if already exists
exists = any(
    entry.get('python_module', {}).get('working_directory') == f'/app/projects/$project_name'
    for entry in workspace['load_from']
)

if not exists:
    workspace['load_from'].append(new_entry)
    print("# Dagster workspace configuration")
    print("# Automatically updated when new projects are deployed")
    print(yaml.dump(workspace, default_flow_style=False, sort_keys=False))
else:
    sys.exit(1)
EOF
    
    if [ $? -eq 0 ]; then
        sudo cp "$temp_file" "$workspace_file"
        echo "✅ Project registered in workspace.yaml"
    else
        echo "ℹ️  Project already registered, skipping"
    fi
    
    rm -f "$temp_file"
}

# Trigger Dagster refresh
trigger_refresh() {
    local efs_mount="$1"
    local project_name="$2"
    local trigger_file="$efs_mount/config/.refresh_trigger"
    
    echo "🔄 Triggering Dagster refresh..."
    
    # Write trigger with timestamp and info
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) - Project: $project_name - Action: deploy" | \
        sudo tee "$trigger_file" > /dev/null
    
    echo "✅ Refresh triggered"
}

# Main execution
echo "🚀 Deploying Dagster project '$PROJECT_NAME'"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Get EFS ID
EFS_ID=$(get_efs_mount)

# Mount EFS
EFS_MOUNT=$(mount_efs "$EFS_ID")

# Deploy project
deploy_to_efs "$PROJECT_NAME" "$PROJECT_PATH" "$EFS_MOUNT"

# Register if requested
if [ "$REGISTER_FLAG" == "--register" ]; then
    register_project "$PROJECT_NAME" "$EFS_MOUNT"
fi

# Trigger refresh
trigger_refresh "$EFS_MOUNT" "$PROJECT_NAME"

# Unmount EFS
echo "🔌 Unmounting EFS..."
sudo umount "$EFS_MOUNT" 2>/dev/null || true

echo ""
echo "✅ Deployment complete!"
echo ""
echo "📋 Next steps:"
echo "   1. Monitor ECS logs: make ecs-logs"
echo "   2. Check Dagster UI for your project"
echo "   3. If project doesn't appear, restart ECS: make deploy-ecs"