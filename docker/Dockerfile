FROM python:3.12-slim

WORKDIR /app

# Install system dependencies including AWS CLI and nginx for auth proxy
RUN apt-get update && apt-get install -y \
    gcc \
    git \
    curl \
    unzip \
    nginx \
    supervisor \
    apache2-utils \
    && rm -rf /var/lib/apt/lists/*

# Install AWS CLI v2 for ARM64
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && ./aws/install \
    && rm -rf awscliv2.zip aws

# Copy requirements and install Python dependencies
COPY pyproject.toml ./
RUN pip install --no-cache-dir -e .

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

# Create dags mount point for EFS volume and dagster home
RUN mkdir -p /app/dags /app/.dagster_home

# Set DAGSTER_HOME
ENV DAGSTER_HOME=/app/.dagster_home

# DAGSTER_S3_BUCKET environment variable is required - must be set at runtime

# Expose nginx port (which proxies to Dagster on port 3000)
EXPOSE 80

# Use entrypoint script to sync DAGs from S3 before starting services
ENTRYPOINT ["./entrypoint.sh"]

# Default command uses supervisor to run both nginx and dagster
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]