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

# Install uv
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

# Copy requirements and install Python dependencies
RUN --mount=type=cache,target=/root/.cache/uv \
  --mount=type=bind,source=uv.lock,target=uv.lock \
  --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
  uv sync --frozen --no-install-project

# Create dagster home directory
RUN mkdir -p /app/.dagster_home /app/dags

# Set DAGSTER_HOME
ENV DAGSTER_HOME=/app/.dagster_home

# Install AWS CLI v2 for ARM64
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip" \
  && unzip awscliv2.zip \
  && ./aws/install \
  && rm -rf awscliv2.zip aws

# Copy multi-repo S3 entrypoint
COPY docker/multi-repo-entrypoint.sh ./multi-repo-entrypoint.sh
RUN chmod +x ./multi-repo-entrypoint.sh

# Expose dagster port directly
EXPOSE 3000

# Production stage with full cloud deployment features
FROM base AS production

# Copy workspace and instance configuration
COPY dagster_config/workspace-production.yaml ./workspace.yaml
COPY dagster_config/dagster-production.yaml ./.dagster_home/dagster.yaml

# Copy the dynamic workspace loader and auto-discovery modules
COPY dagster_config/auto_discover.py ./dagster_config/auto_discover.py
COPY dagster_config/__init__.py ./dagster_config/__init__.py

# Use multi-repo S3 entrypoint - supports multiple repositories
ENTRYPOINT ["/app/multi-repo-entrypoint.sh"]
CMD ["uv", "run", "dagster-webserver", "--host", "0.0.0.0", "--port", "3000", "--workspace", "/app/workspace.yaml"]

# Local development stage - lightweight without cloud dependencies
FROM base AS local

# Copy workspace and instance configuration
COPY dagster_config/workspace-local.yaml ./workspace.yaml
COPY dagster_config/dagster-local.yaml ./.dagster_home/dagster.yaml

# Copy the dynamic workspace loader for local development
COPY dagster_config/auto_discover_local.py ./dagster_config/auto_discover_local.py
COPY dagster_config/__init__.py ./dagster_config/__init__.py

# Simple command that runs dagster directly
ENTRYPOINT ["uv", "run"]
CMD ["dagster-webserver", "--host", "0.0.0.0", "--port", "3000", "--workspace", "/app/workspace.yaml"]
