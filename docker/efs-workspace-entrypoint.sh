#!/bin/bash
# EFS-based workspace management with trigger-based refresh
# Manages workspace.yaml and project deployments on EFS
set -e

echo "$(date): Starting Dagster with EFS workspace support..."

# Configuration
WORKSPACE_CONFIG_PATH="/app/config/workspace.yaml"
PROJECTS_PATH="/app/projects"
REFRESH_TRIGGER_FILE="/app/config/.refresh_trigger"
DAGSTER_HOME="${DAGSTER_HOME:-/app}"

# Function to validate workspace configuration
validate_workspace_config() {
    if [ ! -f "$WORKSPACE_CONFIG_PATH" ]; then
        echo "$(date): WARNING: No workspace.yaml found at $WORKSPACE_CONFIG_PATH"
        echo "$(date): Creating default workspace configuration..."
        
        mkdir -p "$(dirname "$WORKSPACE_CONFIG_PATH")"
        cat > "$WORKSPACE_CONFIG_PATH" << 'EOF'
# Dagster workspace configuration
# Automatically updated when new projects are deployed
load_from: []
EOF
        return 1
    fi
    
    echo "$(date): Validating workspace configuration..."
    python -c "import yaml; yaml.safe_load(open('$WORKSPACE_CONFIG_PATH'))" 2>/dev/null
    return $?
}

# Function to reload Dagster with new workspace configuration
reload_dagster() {
    echo "$(date): Reloading Dagster with updated workspace configuration..."
    
    # Send SIGHUP to Dagster process to reload configuration
    if [ -f "/var/run/dagster.pid" ]; then
        PID=$(cat /var/run/dagster.pid)
        if kill -0 "$PID" 2>/dev/null; then
            echo "$(date): Sending reload signal to Dagster (PID: $PID)..."
            kill -HUP "$PID"
            echo "$(date): Reload signal sent successfully"
        else
            echo "$(date): WARNING: Dagster process not found, restart required"
            return 1
        fi
    else
        echo "$(date): WARNING: No Dagster PID file found"
        return 1
    fi
}

# Function to watch for refresh triggers
watch_for_refresh() {
    echo "$(date): Starting refresh trigger watcher..."
    
    # Create trigger directory if it doesn't exist
    mkdir -p "$(dirname "$REFRESH_TRIGGER_FILE")"
    
    # Initial timestamp
    LAST_MODIFIED=0
    if [ -f "$REFRESH_TRIGGER_FILE" ]; then
        LAST_MODIFIED=$(stat -c %Y "$REFRESH_TRIGGER_FILE" 2>/dev/null || echo 0)
    fi
    
    while true; do
        sleep 2  # Check every 2 seconds
        
        if [ -f "$REFRESH_TRIGGER_FILE" ]; then
            CURRENT_MODIFIED=$(stat -c %Y "$REFRESH_TRIGGER_FILE" 2>/dev/null || echo 0)
            
            if [ "$CURRENT_MODIFIED" -gt "$LAST_MODIFIED" ]; then
                echo "$(date): Refresh trigger detected!"
                
                # Read trigger content for logging
                TRIGGER_INFO=$(cat "$REFRESH_TRIGGER_FILE" 2>/dev/null || echo "No info")
                echo "$(date): Trigger info: $TRIGGER_INFO"
                
                # Validate workspace before reloading
                if validate_workspace_config; then
                    reload_dagster || echo "$(date): Reload failed, Dagster will pick up changes on next restart"
                else
                    echo "$(date): Invalid workspace configuration, skipping reload"
                fi
                
                LAST_MODIFIED=$CURRENT_MODIFIED
            fi
        fi
    done
}

# Function to list deployed projects
list_projects() {
    echo "$(date): Scanning for deployed projects..."
    
    if [ -d "$PROJECTS_PATH" ]; then
        PROJECT_COUNT=$(find "$PROJECTS_PATH" -mindepth 1 -maxdepth 1 -type d | wc -l)
        echo "$(date): Found $PROJECT_COUNT projects:"
        
        for project_dir in "$PROJECTS_PATH"/*; do
            if [ -d "$project_dir" ]; then
                PROJECT_NAME=$(basename "$project_dir")
                
                # Check if it's a valid Dagster project
                if [ -f "$project_dir/pyproject.toml" ] || [ -f "$project_dir/setup.py" ]; then
                    echo "  ✓ $PROJECT_NAME (valid Dagster project)"
                    
                    # Count Python files
                    PY_COUNT=$(find "$project_dir" -name "*.py" -type f | wc -l)
                    echo "    - $PY_COUNT Python files"
                else
                    echo "  ✗ $PROJECT_NAME (missing pyproject.toml or setup.py)"
                fi
            fi
        done
    else
        echo "$(date): No projects directory found at $PROJECTS_PATH"
    fi
}

# Function to setup EFS permissions
setup_efs_permissions() {
    echo "$(date): Setting up EFS permissions..."
    
    # Ensure directories exist with proper permissions
    mkdir -p "$PROJECTS_PATH" "$(dirname "$WORKSPACE_CONFIG_PATH")"
    chmod 755 "$PROJECTS_PATH" "$(dirname "$WORKSPACE_CONFIG_PATH")"
    
    # Set ownership if running as root
    if [ "$(id -u)" = "0" ]; then
        chown -R dagster:dagster "$PROJECTS_PATH" "$(dirname "$WORKSPACE_CONFIG_PATH")" 2>/dev/null || true
    fi
}

# Main execution
echo "$(date): Initializing EFS workspace environment..."

# Setup permissions
setup_efs_permissions

# Validate initial workspace configuration
if ! validate_workspace_config; then
    echo "$(date): No valid workspace configuration found"
fi

# List current projects
list_projects

# Copy workspace config to Dagster home if different
if [ "$WORKSPACE_CONFIG_PATH" != "$DAGSTER_HOME/workspace.yaml" ]; then
    echo "$(date): Linking workspace configuration to Dagster home..."
    ln -sf "$WORKSPACE_CONFIG_PATH" "$DAGSTER_HOME/workspace.yaml"
fi

# Start refresh watcher in background
watch_for_refresh &
WATCHER_PID=$!
echo "$(date): Refresh watcher started (PID: $WATCHER_PID)"

# Store Dagster PID for reload functionality
echo "$(date): Starting Dagster process: $@"
exec "$@" &
DAGSTER_PID=$!
echo "$DAGSTER_PID" > /var/run/dagster.pid

# Wait for Dagster process
wait "$DAGSTER_PID"