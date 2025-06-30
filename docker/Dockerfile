# Base stage with common dependencies
FROM python:3.12-slim AS base

WORKDIR /app

# Install base system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    git \
    curl \
    unzip \
    libpq-dev \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install Python dependencies
COPY pyproject.toml ./
RUN pip install --no-cache-dir -e .

# Create dagster home directory
RUN mkdir -p /app/.dagster_home /app/dags

# Set DAGSTER_HOME
ENV DAGSTER_HOME=/app/.dagster_home

# Production stage with full cloud deployment features
FROM base AS production

# Install additional production dependencies (AWS CLI, nginx, supervisor)
RUN apt-get update && apt-get install -y \
    nginx \
    supervisor \
    apache2-utils \
    && rm -rf /var/lib/apt/lists/*

# Install AWS CLI v2 for ARM64
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && ./aws/install \
    && rm -rf awscliv2.zip aws

# Copy workspace and instance configuration
COPY docker/workspace-production.yaml ./workspace.yaml
COPY docker/dagster-production.yaml ./.dagster_home/dagster.yaml

# Copy a minimal test DAG to ensure Dagster can start even if S3 sync fails
COPY test_dag.py ./test_dag.py

# Copy nginx configuration
COPY docker/nginx.conf /etc/nginx/sites-available/default
RUN rm -f /etc/nginx/sites-enabled/default && \
    ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default

# Copy supervisor configuration for running both nginx and dagster
COPY docker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Copy entrypoint and sync scripts
COPY docker/entrypoint.sh ./entrypoint.sh
COPY docker/sync-from-s3.sh ./sync-from-s3.sh
RUN chmod +x ./entrypoint.sh ./sync-from-s3.sh

# DAGSTER_S3_BUCKET environment variable is required - must be set at runtime

# Expose nginx port (which proxies to Dagster on port 3000)
EXPOSE 80

# Use entrypoint script to sync DAGs from S3 before starting services
ENTRYPOINT ["./entrypoint.sh"]

# Default command uses supervisor to run both nginx and dagster
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]

# Local development stage - lightweight without cloud dependencies
FROM base AS local

# Install AWS CLI v2 for ARM64 (needed for S3 sync in local dev)
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && ./aws/install \
    && rm -rf awscliv2.zip aws

# Copy fallback files (used when S3 sync is disabled)
COPY dags/ /app/dags/
COPY docker/workspace-local.yaml /app/workspace.yaml

# Copy entrypoint and sync scripts (same as production)
COPY docker/entrypoint.sh ./entrypoint.sh
COPY docker/sync-from-s3.sh ./sync-from-s3.sh
RUN chmod +x ./entrypoint.sh ./sync-from-s3.sh

# Expose dagster port directly (no nginx proxy needed for local dev)
EXPOSE 3000

# Use same entrypoint as production for S3 sync consistency
ENTRYPOINT ["./entrypoint.sh"]

# Simple command that runs dagster directly (passed to entrypoint)
CMD ["dagster-webserver", "--host", "0.0.0.0", "--port", "3000", "--workspace", "/app/workspace.yaml"]