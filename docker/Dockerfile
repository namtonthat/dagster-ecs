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
COPY workspace.yaml ./
COPY dagster.yaml ./.dagster_home/dagster.yaml

# Copy nginx configuration
COPY docker/nginx.conf /etc/nginx/sites-available/default
RUN rm -f /etc/nginx/sites-enabled/default && \
    ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default

# Copy supervisor configuration for running both nginx and dagster
COPY docker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Copy entrypoint script
COPY docker/entrypoint.sh ./entrypoint.sh
RUN chmod +x ./entrypoint.sh

# DAGSTER_S3_BUCKET environment variable is required - must be set at runtime

# Expose nginx port (which proxies to Dagster on port 3000)
EXPOSE 80

# Use entrypoint script to sync DAGs from S3 before starting services
ENTRYPOINT ["./entrypoint.sh"]

# Default command uses supervisor to run both nginx and dagster
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]

# Local development stage - lightweight without cloud dependencies
FROM base AS local

# Copy application code and configuration
COPY dags/ /app/dags/
COPY workspace.yaml /app/

# Expose dagster port directly (no nginx proxy needed for local dev)
EXPOSE 3000

# Override entrypoint from production stage - use default entrypoint for local
ENTRYPOINT []

# Simple command that runs dagster directly
CMD ["dagster-webserver", "--host", "0.0.0.0", "--port", "3000", "--workspace", "/app/workspace.yaml"]