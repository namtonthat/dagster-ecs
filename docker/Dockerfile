FROM python:3.12-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    git \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install Python dependencies
COPY pyproject.toml ./
RUN pip install --no-cache-dir -e .

# Create dags mount point for EFS volume and dagster home
RUN mkdir -p /app/dags /app/.dagster_home

# Set DAGSTER_HOME
ENV DAGSTER_HOME=/app/.dagster_home

# Expose Dagster webserver port
EXPOSE 3000

# Default command for webserver (can be overridden for daemon/grpc)
CMD ["dagster-webserver", "--host", "0.0.0.0", "--port", "3000", "--workspace", "/app/workspace.yaml"]