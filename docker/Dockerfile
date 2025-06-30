FROM python:3.12-slim

WORKDIR /app

# Install system dependencies including AWS CLI for S3 sync
RUN apt-get update && apt-get install -y \
    gcc \
    git \
    curl \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Install AWS CLI v2 for ARM64
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && ./aws/install \
    && rm -rf awscliv2.zip aws

# Copy requirements and install Python dependencies
COPY pyproject.toml ./
RUN pip install --no-cache-dir -e .

# Copy workspace configuration
COPY workspace.yaml ./

# Copy entrypoint script
COPY docker/entrypoint.sh ./entrypoint.sh
RUN chmod +x ./entrypoint.sh

# Create dags mount point for EFS volume and dagster home
RUN mkdir -p /app/dags /app/.dagster_home

# Set DAGSTER_HOME
ENV DAGSTER_HOME=/app/.dagster_home

# DAGSTER_S3_BUCKET environment variable is required - must be set at runtime

# Expose Dagster webserver port
EXPOSE 3000

# Use entrypoint script to sync DAGs from S3 before starting Dagster
ENTRYPOINT ["./entrypoint.sh"]

# Default command for webserver (can be overridden for daemon/grpc)
CMD ["dagster-webserver", "--host", "0.0.0.0", "--port", "3000", "--workspace", "/app/workspace.yaml"]