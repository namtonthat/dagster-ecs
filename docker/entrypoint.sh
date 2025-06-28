#!/bin/bash
set -e

# Fix permissions for dagster home directory
if [ "$(id -u)" = '0' ]; then
    # Running as root, fix permissions and switch to dagster user
    chown -R dagster:dagster /app/.dagster_home /app/dags
    exec gosu dagster "$@"
else
    # Already running as non-root user
    exec "$@"
fi