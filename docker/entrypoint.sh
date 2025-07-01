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

  # Create nginx directory if it doesn't exist (for production)
  if [ -d "/etc/nginx" ] || [ "$AWS_ACCESS_KEY_ID" != "local" ]; then
    mkdir -p /etc/nginx
    # Generate .htpasswd file
    echo "$DAGSTER_AUTH_USER:$(openssl passwd -apr1 "$DAGSTER_AUTH_PASSWORD")" >/etc/nginx/.htpasswd
    echo "Basic auth configured for user: $DAGSTER_AUTH_USER"
    echo "WARNING: Using default credentials! Set DAGSTER_AUTH_USER and DAGSTER_AUTH_PASSWORD environment variables for security."
  else
    echo "Skipping basic auth setup for local development"
  fi
}

# Check if running in local development mode
# if [ "$AWS_ACCESS_KEY_ID" = "local" ] || [ "$AWS_SECRET_ACCESS_KEY" = "local" ]; then
#     echo "Detected local development mode, skipping auth setup and S3 sync..."
#     SYNC_PID=""
# else
#     # Setup authentication for production
#     setup_auth
# fi

# Fix permissions for dagster home directory
if [ "$(id -u)" = '0' ]; then
  # Running as root, fix permissions
  chown -R root:root /app/.dagster_home /app/dags 2>/dev/null || true
fi

# Set up signal handlers
trap cleanup SIGTERM SIGINT

# Execute the original command
echo "Starting Dagster with command: $@"
exec "$@"

