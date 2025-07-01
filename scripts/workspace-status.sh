#!/bin/bash
set -e

# Script to check workspace status on EFS
# Shows current projects and workspace configuration

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Get EFS ID from terraform outputs
get_efs_id() {
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

# Mount EFS temporarily
mount_efs_readonly() {
    local efs_id="$1"
    local mount_point="/tmp/dagster-efs-readonly-$$"
    
    # Create temporary mount point
    mkdir -p "$mount_point"
    
    # Try to mount (read-only)
    echo "🔗 Mounting EFS for status check..."
    
    # Get DNS name
    DNS_NAME="$efs_id.efs.$AWS_DEFAULT_REGION.amazonaws.com"
    
    # Mount with read-only option
    sudo mount -t nfs4 -o nfsvers=4.1,ro,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport \
        "$DNS_NAME:/" "$mount_point" 2>/dev/null || {
        echo "❌ Failed to mount EFS. Ensure you have proper permissions."
        rmdir "$mount_point"
        exit 1
    }
    
    echo "$mount_point"
}

# Display workspace configuration
show_workspace_config() {
    local mount_point="$1"
    local workspace_file="$mount_point/config/workspace.yaml"
    
    echo ""
    echo "📋 Workspace Configuration"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if [ -f "$workspace_file" ]; then
        echo "Location: /config/workspace.yaml"
        echo ""
        echo "Registered Projects:"
        
        # Parse workspace.yaml to list projects
        python3 - "$workspace_file" << 'EOF'
import yaml
import sys

workspace_file = sys.argv[1]

try:
    with open(workspace_file, 'r') as f:
        workspace = yaml.safe_load(f)
    
    if not workspace or 'load_from' not in workspace:
        print("  (No projects registered)")
    else:
        projects = workspace.get('load_from', [])
        if not projects:
            print("  (No projects registered)")
        else:
            for i, entry in enumerate(projects, 1):
                if 'python_module' in entry:
                    module = entry['python_module']
                    name = module.get('module_name', 'Unknown').split('.')[0]
                    path = module.get('working_directory', 'Unknown')
                    print(f"  {i}. {name}")
                    print(f"     Module: {module.get('module_name', 'Unknown')}")
                    print(f"     Path: {path}")
                    print()
except Exception as e:
    print(f"  Error reading workspace: {e}")
EOF
    else:
        echo "  ⚠️  No workspace.yaml found"
    fi
}

# Display deployed projects
show_deployed_projects() {
    local mount_point="$1"
    local projects_dir="$mount_point/projects"
    
    echo ""
    echo "📁 Deployed Projects"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if [ -d "$projects_dir" ]; then
        local project_count=$(find "$projects_dir" -mindepth 1 -maxdepth 1 -type d | wc -l)
        echo "Total: $project_count projects"
        echo ""
        
        for project_path in "$projects_dir"/*; do
            if [ -d "$project_path" ]; then
                local project_name=$(basename "$project_path")
                local py_count=$(find "$project_path" -name "*.py" -type f | wc -l)
                local last_modified=$(stat -c %y "$project_path" 2>/dev/null | cut -d' ' -f1 || echo "Unknown")
                
                echo "  📦 $project_name"
                echo "     Python files: $py_count"
                echo "     Last modified: $last_modified"
                
                # Check for key files
                if [ -f "$project_path/pyproject.toml" ]; then
                    echo "     ✓ pyproject.toml found"
                elif [ -f "$project_path/setup.py" ]; then
                    echo "     ✓ setup.py found"
                else
                    echo "     ⚠️  No pyproject.toml or setup.py"
                fi
                
                # Check for definitions module
                if find "$project_path" -name "definitions.py" | grep -q .; then
                    echo "     ✓ definitions.py found"
                else
                    echo "     ⚠️  No definitions.py found"
                fi
                
                echo ""
            fi
        done
    else {
        echo "  ⚠️  No projects directory found"
    fi
}

# Check last refresh trigger
show_refresh_status() {
    local mount_point="$1"
    local trigger_file="$mount_point/config/.refresh_trigger"
    
    echo "🔄 Refresh Status"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if [ -f "$trigger_file" ]; then
        echo "Last refresh trigger:"
        cat "$trigger_file" | sed 's/^/  /'
    else
        echo "  No refresh triggers found"
    fi
}

# Main execution
echo "🔍 Dagster ECS Workspace Status"
echo "================================"

# Get EFS ID
EFS_ID=$(get_efs_id)
echo "EFS ID: $EFS_ID"

# Mount EFS read-only
MOUNT_POINT=$(mount_efs_readonly "$EFS_ID")

# Show workspace configuration
show_workspace_config "$MOUNT_POINT"

# Show deployed projects
show_deployed_projects "$MOUNT_POINT"

# Show refresh status
show_refresh_status "$MOUNT_POINT"

# Cleanup
echo ""
echo "🔌 Cleaning up..."
sudo umount "$MOUNT_POINT" 2>/dev/null || true
rmdir "$MOUNT_POINT" 2>/dev/null || true

echo ""
echo "✅ Status check complete"