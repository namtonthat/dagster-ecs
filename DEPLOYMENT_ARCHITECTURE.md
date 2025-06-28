# Dagster ECS External Repository Deployment Architecture

## Overview

This system enables dynamic deployment of external Dagster repositories into the ECS-based Dagster deployment. Each external repository becomes a separate code location with isolated S3 storage.

## Architecture Components

### 1. Code Location Management
- **Main Dagster Instance**: Central webserver and daemon running on ECS
- **Code Location Services**: Separate ECS services for each external repository
- **Dynamic Registration**: Code locations registered via workspace configuration

### 2. S3 Prefix Isolation
- **Bucket Structure**: `dagster-storage/repos/{repo-name}/{asset-path}`
- **Asset Isolation**: Each repository gets its own S3 prefix
- **Cross-Repository Access**: Controlled via IAM policies

### 3. Repository Deployment Pipeline
- **Git Integration**: Clone external repositories into deployment containers
- **Build Process**: Create repository-specific Docker images
- **ECS Deployment**: Deploy as separate ECS services
- **Registration**: Auto-register with main Dagster instance

## Workflow

### Adding a New Repository

1. **Repository Registration**
   ```bash
   make add-repo REPO_URL=https://github.com/user/repo.git REPO_NAME=my-pipeline
   ```

2. **Automatic Process**
   - Clone repository
   - Build Docker image with repository code
   - Deploy as new ECS service
   - Register code location in workspace
   - Configure S3 prefix: `repos/my-pipeline/`

3. **Asset Execution**
   - Assets run in isolated code location
   - S3 writes go to `repos/my-pipeline/assets/`
   - Logs isolated per repository

### S3 Bucket Structure
```
dagster-storage/
├── repos/
│   ├── repo-1/
│   │   ├── assets/
│   │   ├── runs/
│   │   └── logs/
│   ├── repo-2/
│   │   ├── assets/
│   │   ├── runs/
│   │   └── logs/
│   └── shared/           # Cross-repository shared data
├── system/               # Dagster system storage
└── temp/                # Temporary processing
```

## Implementation Components

### 1. Repository Manager Service
- REST API for repository management
- Git operations (clone, pull, build)
- ECS service lifecycle management
- Workspace configuration updates

### 2. Code Location Template
- Base Docker image with common dependencies
- Dynamic repository mounting
- S3 configuration injection
- Resource isolation

### 3. Infrastructure Extensions
- Additional ECS task definitions
- IAM roles per code location
- Load balancer target groups
- CloudWatch log groups

## Configuration

### Repository Specification
```yaml
# repos/my-pipeline/config.yml
name: my-pipeline
git_url: https://github.com/user/repo.git
branch: main
python_file: my_pipeline/definitions.py
resources:
  cpu: 256
  memory: 512
s3_prefix: repos/my-pipeline
environment:
  - name: CUSTOM_VAR
    value: custom_value
```

### Workspace Configuration
```yaml
# workspace.yaml (auto-generated)
load_from:
  - grpc_server:
      host: my-pipeline-service.local
      port: 4000
      location_name: my-pipeline
```

## Security & Isolation

### IAM Policies
- Each code location has specific S3 prefix access
- Cross-repository access via explicit policies
- Read-only access to shared resources

### Network Isolation
- Code locations in private subnets
- Internal communication only
- Centralized logging and monitoring

## Commands

### Repository Management
```bash
make add-repo REPO_URL=<url> REPO_NAME=<name>    # Add new repository
make update-repo REPO_NAME=<name>                # Update repository code
make remove-repo REPO_NAME=<name>                # Remove repository
make list-repos                                  # List all repositories
make repo-logs REPO_NAME=<name>                  # View repository logs
```

### Development Workflow
```bash
make dev-with-repos        # Start local dev with all repositories
make dev-add-repo          # Add repository to local development
make sync-repos            # Sync all repositories from remote
```