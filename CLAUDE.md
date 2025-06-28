# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains a Dagster deployment configuration for AWS ECS. The project is designed to deploy Dagster (a data orchestration platform) on Amazon ECS infrastructure using OpenTofu (an open-source Terraform alternative) for infrastructure provisioning.

## Key Technologies

- **Dagster**: Data orchestration platform for building, testing, and monitoring data pipelines
- **AWS ECS**: Container orchestration service for running Dagster components
- **OpenTofu**: Infrastructure as Code tool (Terraform alternative) for AWS resource provisioning
- **Makefile**: Command abstraction layer for common development and deployment tasks

## Design Principles

- **Minimal, Clean Code**: Keep the codebase lean with only essential components
- **Local Development First**: Ensure full local development capability before cloud deployment
- **CI/CD Integration**: Automatic deployment to AWS on push/merge to main branch
- **Maintainable Infrastructure**: Simple, well-documented OpenTofu configurations

## Architecture Goals

Implement a minimal but production-ready Dagster deployment:
- **Local Development**: Full Dagster stack running locally with Docker Compose
- **Cloud Deployment**: Streamlined ECS deployment with minimal AWS resources
- **Essential Components Only**:
  - Dagster webserver (UI/API)
  - Dagster daemon (orchestration)
  - PostgreSQL (RDS for cloud, local container for dev)
  - S3 bucket for assets/logs
  - Basic networking (VPC, subnets, security groups)

## Development Workflow

### Local Development
```bash
make dev           # Start local Dagster stack with Docker Compose
make stop          # Stop local environment
make dev-logs      # View local logs
make dev-reset     # Reset local database and restart
```

### Repository Management (External DAGs)
```bash
# Add external repository as code location
make add-repo REPO_URL=https://github.com/user/repo.git REPO_NAME=my-pipeline

# Manage repositories
make update-repo REPO_NAME=my-pipeline   # Update repository code
make remove-repo REPO_NAME=my-pipeline   # Remove repository
make list-repos                          # List all repositories
make repo-logs REPO_NAME=my-pipeline     # View repository logs
```

### Deployment Commands
```bash
# Infrastructure management
make infra-init    # Initialize OpenTofu backend
make infra-plan    # Preview infrastructure changes  
make infra-apply   # Apply infrastructure changes
make infra-destroy # Destroy infrastructure

# Application deployment
make build         # Build and tag Docker images
make push          # Push images to ECR
make deploy        # Deploy latest images to ECS
make logs          # View ECS service logs
```

### CI/CD Integration
- **Trigger**: Push/merge to main branch
- **Process**: Build → Test → Push to ECR → Deploy to ECS
- **Tools**: GitHub Actions or similar pipeline

### S3 Prefix Isolation
Each external repository gets isolated S3 storage:
- **Pattern**: `s3://bucket/repos/{repo-name}/assets/`
- **Auto-configuration**: Repositories automatically get their prefix
- **Cross-repo access**: Controlled via IAM policies

## Reference Implementation

This project follows the pattern from: https://github.com/dagster-io/dagster/tree/master/examples/deploy_ecs

Key differences:
- Uses OpenTofu instead of Terraform
- Includes Makefile for command abstraction
- May include additional customizations for specific deployment needs

## File Structure (Implemented)

```
├── dagster_code/           # Main Dagster pipeline definitions
│   ├── __init__.py        # Main definitions with S3 resources
│   ├── assets.py          # Sample assets
│   ├── jobs.py            # Sample jobs  
│   └── resources.py       # S3 prefix isolation resources
├── repository_manager/     # External repository management
│   └── manager.py         # Repository deployment automation
├── infrastructure/        # OpenTofu configuration files
│   ├── main.tf           # Main configuration
│   ├── vpc.tf            # VPC and networking
│   ├── ecs.tf            # ECS cluster and services
│   ├── rds.tf            # PostgreSQL database
│   ├── s3.tf             # S3 storage bucket
│   ├── service_discovery.tf # ECS service discovery
│   └── ...               # Other infrastructure components
├── docker/
│   └── Dockerfile        # Single optimized container
├── docker-compose.yml    # Local development environment
├── workspace.yaml        # Dagster workspace configuration
├── Makefile             # Command abstractions
├── .github/workflows/   # CI/CD pipeline
├── pyproject.toml       # Python dependencies
├── DEPLOYMENT_ARCHITECTURE.md # Detailed architecture docs
└── repos/               # Cloned external repositories (runtime)
```

## Key Implementation Notes

- **External Repository Integration**: Add any Git repository as a Dagster code location
- **S3 Prefix Isolation**: Each repository gets isolated S3 storage with automatic prefixes
- **Service Discovery**: ECS services use AWS Cloud Map for internal communication
- **Local-First Development**: Full local development with Docker Compose
- **Repository Management**: Python-based automation for cloning, building, and deploying repositories
- **Infrastructure as Code**: Complete OpenTofu configuration for AWS ap-southeast-2
- **Monitoring**: CloudWatch logging with per-repository log groups