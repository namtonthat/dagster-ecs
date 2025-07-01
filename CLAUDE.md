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

Implement a minimal but production-ready Dagster deployment with dynamic DAG loading:
- **Local Development**: Full Dagster stack running locally with Docker Compose
- **Cloud Deployment**: Streamlined ECS deployment with minimal AWS resources
- **Dynamic DAG Loading**: DAG files stored in S3 and synced dynamically to containers
- **Cost-Optimized**: Designed for AWS Free Tier with automatic scaling
- **Essential Components Only**:
  - Dagster webserver (UI/API) with S3-synced DAGs
  - Dagster daemon (orchestration)
  - PostgreSQL (RDS for cloud, local container for dev)
  - S3 bucket for DAG files, assets, and logs
  - AWS Secrets Manager for secure credential management
  - Basic networking (VPC, subnets, security groups)

## Cost Structure & Scalability

### Low-Cost Design
This deployment is optimized for **minimal AWS costs** while maintaining production capabilities:

**AWS Free Tier Utilization:**
- **ECS Fargate**: 0.25 vCPU, 512MB RAM with ARM64 architecture (~$3-5/month)
- **RDS PostgreSQL**: db.t3.micro instance (Free Tier: 750 hours/month)
- **EFS Storage**: Burst mode (Free Tier: 5GB storage)
- **S3 Storage**: Standard tier (Free Tier: 5GB)
- **CloudWatch Logs**: 5GB/month included in Free Tier

**Estimated Monthly Cost:**
- **Within Free Tier**: ~$0-5/month for light usage (2-3 users)
- **Post Free Tier**: ~$15-25/month for sustained usage
- **Cost Scaling**: Automatic resource scaling based on actual demand

### High Scalability Features

**Automatic Scaling:**
- **ECS Auto Scaling**: 1-2 instances based on CPU (70%) and memory (80%) thresholds
- **Database Scaling**: RDS supports vertical scaling when needed
- **Storage Scaling**: S3 and EFS automatically scale with usage

**Performance Optimizations:**
- **ARM64 Architecture**: ~20% cost savings over x86 instances
- **Burst Mode EFS**: Cost-effective storage with performance bursting
- **Container Optimization**: Minimal resource allocation for 2-3 concurrent users

**Scalability Capacity:**
- **Current Config**: Supports 2-3 concurrent users comfortably
- **Scale-Up Path**: Easy resource adjustment for 10+ users
- **Multi-Repository**: Isolated S3 storage per external repository

## Development Workflow

### Local Development
```bash
make start         # Start local Dagster stack with Docker Compose
make stop          # Stop local environment  
make logs          # View local logs
make reset         # Reset local database and restart
make build-local   # Build Docker image for local development
make install       # Install Python dependencies with uv
```

### DAG Development
```bash
make create dag=my_pipeline    # Create new DAG from template (calls scripts/create-dag.sh)
make test                      # Run type checking, linting, and tests (calls scripts/test.sh)
```

### Authentication Management
```bash
make auth-generate user=admin pass=secret  # Generate htpasswd entry
make auth-deploy user=admin pass=secret    # Deploy new auth credentials
make auth-show                             # Show current authentication configuration
```

### Deployment Commands
```bash
# Infrastructure management
make infra-init    # Initialize OpenTofu backend
make infra-plan    # Preview infrastructure changes  
make infra-apply   # Apply infrastructure changes
make infra-destroy # Destroy infrastructure

# Application deployment
make build         # Build and tag Docker images (default: production target)
make push          # Push images to ECR
make deploy-dags   # Deploy DAG files and workspace to S3
make deploy-ecs    # Deploy latest images to ECS Fargate
make deploy-all    # Deploy DAGs to S3 AND restart ECS service
make ecs-logs      # View ECS Fargate logs

# Information & credentials
make aws-url       # Show Dagster web UI URL
make aws-account-id # Show AWS Account ID
make aws-credentials # Show AWS credentials (access key + secret key, one per line)
make help          # Show all available commands (auto-generated)
```

### CI/CD Integration
- **Trigger**: Push/merge to main branch
- **Process**: Build → Test → Push to ECR → Deploy to ECS
- **Tools**: GitHub Actions pipeline configured in `.github/workflows/deploy.yml`

## Reference Implementation

This project follows the pattern from: https://github.com/dagster-io/dagster/tree/master/examples/deploy_ecs

Key differences:
- Uses OpenTofu instead of Terraform
- Includes Makefile for command abstraction
- May include additional customizations for specific deployment needs

## File Structure (Current)

```
├── dags/                    # Dagster pipeline definitions
│   ├── __init__.py         # Package initialization
│   └── dagster_quickstart/ # Sample quickstart project
│       └── defs/
│           ├── assets.py   # Sample assets
│           └── data/       # Sample data files
├── dagster/                # Dagster configuration files
│   ├── dagster-local.yaml  # Local development config
│   ├── dagster-production.yaml # Production config
│   ├── workspace-local.yaml     # Local workspace config
│   └── workspace-production.yaml # Production workspace config
├── infrastructure/         # OpenTofu configuration files
│   ├── main.tf            # Main configuration
│   ├── vpc.tf             # VPC and networking
│   ├── ecs_fargate.tf     # ECS cluster and services
│   ├── rds.tf             # PostgreSQL database
│   ├── s3.tf              # S3 storage bucket
│   ├── ecr.tf             # Elastic Container Registry
│   ├── iam.tf             # IAM roles and policies
│   ├── load_balancer.tf   # Application Load Balancer
│   ├── outputs.tf         # Output values
│   ├── variables.tf       # Input variables
│   ├── backend.hcl        # Backend configuration
│   └── terraform.tfvars*  # Variable values
├── docker/                # Docker configuration
│   ├── Dockerfile         # Multi-stage container build
│   ├── entrypoint.sh      # Container entrypoint script
│   ├── sync-from-s3.sh    # S3 sync script
│   ├── generate-htpasswd.sh # Auth generation script
│   ├── nginx.conf         # Nginx configuration
│   └── supervisord.conf   # Supervisor configuration
├── scripts/               # Automation scripts
│   ├── create-dag.sh      # DAG creation script
│   ├── deploy-dags.sh     # DAG deployment script
│   ├── deploy-workspace.sh # Workspace deployment script
│   ├── manage-auth.sh     # Authentication management
│   ├── push.sh            # ECR push script
│   └── test.sh            # Testing script
├── templates/             # Code templates
│   └── dag.py             # DAG template
├── docs/                  # Documentation
│   ├── architecture.md    # Architecture documentation
│   └── deployment.md      # Deployment documentation
├── .github/workflows/     # CI/CD pipeline
│   └── deploy.yml         # GitHub Actions deployment
├── docker-compose.yml     # Local development environment
├── workspace.yaml         # Dagster workspace configuration
├── Makefile              # Command abstractions
├── pyproject.toml        # Python dependencies and project config
├── uv.lock               # UV lockfile
└── README.md             # Project documentation
```

## Key Implementation Notes

### Current State
- **Infrastructure**: Uses OpenTofu (Terraform alternative) for AWS resource provisioning
- **Container Registry**: ECR for Docker image storage and deployment
- **Multi-Stage Build**: Dockerfile with separate local and production stages
- **Load Balancer**: Application Load Balancer for public access to Dagster UI
- **Authentication**: HTTP basic auth support with htpasswd generation scripts
- **Local Development**: Full Docker Compose stack for local development
- **Python Package Management**: Uses UV for fast dependency management
- **Code Organization**: Simple structure with sample assets in `dags/dagster_quickstart/`

### Development Features
- **ARM64 Support**: Optimized for AWS Graviton processors (cost savings)
- **Multi-Target Build**: Separate Docker targets for local and production environments
- **Workspace Configuration**: Separate configs for local and production Dagster workspaces
- **Script Automation**: Comprehensive script collection for deployment and management
- **Template System**: DAG template for rapid pipeline creation
- **Testing Integration**: Automated testing with ruff linting and type checking
- **Documentation**: Architecture and deployment docs in `docs/` directory

### Infrastructure Components
- **ECS Fargate**: Serverless container deployment
- **RDS PostgreSQL**: Managed database service
- **S3**: Object storage for assets and logs
- **VPC**: Isolated network environment
- **IAM**: Role-based access control
- **CloudWatch**: Logging and monitoring
- **Application Load Balancer**: Public access and SSL termination