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
  uv sync --locked --no-install-project --no-editable

# Create dagster home directory
RUN mkdir -p /app/.dagster_home /app/dags

# Set DAGSTER_HOME
ENV DAGSTER_HOME=/app/.dagster_home

# Install AWS CLI v2 for ARM64
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip" \
  && unzip awscliv2.zip \
  && ./aws/install \
  && rm -rf awscliv2.zip aws

# No longer using S3 sync entrypoints - DAGs are built into the image

# Expose dagster port directly
EXPOSE 3000

# Copy the same workspace file
COPY dagster_config/workspace.yaml ./workspace.yaml

# Production stage with full cloud deployment features
FROM base AS production

# Copy workspace and instance configuration
COPY dagster_config/dagster-production.yaml ./.dagster_home/dagster.yaml

# Direct entrypoint - no S3 sync needed
ENTRYPOINT ["uv", "run"]
CMD ["dagster-webserver", "--host", "0.0.0.0", "--port", "3000", "--workspace", "/app/workspace.yaml"]

# Local development stage - lightweight without cloud dependencies
FROM base AS local

# Copy workspace and instance configuration
COPY dagster_config/dagster-local.yaml ./.dagster_home/dagster.yaml

# No dynamic workspace loading - using static workspace.yaml

# Simple command that runs dagster directly
ENTRYPOINT ["uv", "run"]
CMD ["dagster-webserver", "--host", "0.0.0.0", "--port", "3000", "--workspace", "/app/workspace.yaml"]
