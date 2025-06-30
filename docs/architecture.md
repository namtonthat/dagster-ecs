# Dagster ECS Architecture & Infrastructure

## Overview

This document describes the complete architecture of the Dagster ECS Fargate deployment - a cost-optimized, production-ready data orchestration platform running on AWS. The system features **dynamic DAG loading** from S3, eliminating Docker rebuilds for pipeline changes and enabling rapid development cycles.

## 🏗️ System Architecture

### High-Level Components

```mermaid
graph TB
    subgraph "Internet"
        Users[Users/Developers]
    end
    
    subgraph "AWS ap-southeast-2 (vpc-03a6c5433c1e0bb48)"
        subgraph "Public Subnet A (10.0.1.0/24)"
            ALB[Application Load Balancer<br/>dagster-ecs-alb-1680764756<br/>Port 80 HTTP]
            ECS_WEB[ECS Fargate Task<br/>Dagster Webserver<br/>ARM64 - 0.25vCPU/512MB]
        end
        
        subgraph "Public Subnet B (10.0.2.0/24)"
            ECS_DAEMON[ECS Fargate Task<br/>Dagster Daemon<br/>ARM64 - 0.25vCPU/512MB]
            RDS[(PostgreSQL RDS<br/>db.t3.micro)]
        end
        
        subgraph "Storage & Services"
            S3[S3 Bucket<br/>DAG Files & Assets]
            EFS[EFS File System<br/>Cross-AZ Sync]
            ECR[ECR Repository<br/>ARM64 Images]
        end
        
        subgraph "Security"
            SM[Secrets Manager<br/>Credentials]
            IAM[IAM Roles<br/>Access Control]
        end
    end
    
    Users --> ALB
    ALB --> ECS_WEB
    ECS_WEB --> RDS
    ECS_WEB --> S3
    ECS_DAEMON --> RDS
    ECS_DAEMON --> S3
    
    style ALB fill:#e1f5fe
    style ECS_WEB fill:#e8f5e8
    style ECS_DAEMON fill:#e8f5e8
    style RDS fill:#fff3e0
    style S3 fill:#f3e5f5
```

### Infrastructure Specifications

| Component | Configuration | Purpose |
|-----------|---------------|---------|
| **ECS Fargate** | 0.25 vCPU, 512MB RAM (ARM64) | Container runtime |
| **PostgreSQL RDS** | db.t3.micro (Free Tier) | Metadata storage |
| **Application Load Balancer** | Multi-AZ, health checks | Traffic routing |
| **S3 Bucket** | Standard tier | DAG files & assets |
| **EFS File System** | Burst mode, multi-AZ | Shared storage |
| **ECR Repository** | ARM64 images | Container registry |

## 🔄 Dynamic DAG Loading System

### Architecture Benefits

**Traditional Approach:**
```
DAG Change → Docker Build → ECR Push → ECS Deploy → 5-10 minutes
```

**Our Dynamic Loading:**
```
DAG Change → S3 Upload → Auto-Sync → 60 seconds
```

### S3 Sync Flow

```mermaid
sequenceDiagram
    participant Dev as Developer
    participant S3 as S3 Bucket
    participant ECS as ECS Container
    participant Dagster as Dagster UI
    
    Dev->>S3: 1. Upload DAG files<br/>make deploy-dags
    S3->>S3: 2. Files stored in /dags/
    
    loop Every 10 minutes
        ECS->>S3: 3. aws s3 sync (timeout 30s)
        S3->>ECS: 4. Download new/changed files
        ECS->>ECS: 5. Update local /app/dags/
    end
    
    ECS->>Dagster: 6. Dagster auto-detects changes
    Dagster->>Dagster: 7. Reload DAG definitions
    
    Dev->>Dagster: 8. View updated DAGs
```

### Container Sync Process

1. **Initial Sync**: On container startup, sync DAGs and workspace from S3
2. **Periodic Sync**: Background process syncs every 10 minutes
3. **Error Handling**: Detailed logging and failure detection
4. **Credential Validation**: Tests AWS credentials before sync
5. **Local Fallback**: Uses local files when S3 sync is disabled

## 🌐 Network Architecture

### VPC Configuration
- **CIDR**: 10.0.0.0/16 (65,536 IPs)
- **Subnets**: 2 public subnets across AZs
- **Internet Gateway**: Direct internet access
- **Route Tables**: Default route to internet gateway

### Security Groups

```mermaid
graph LR
    subgraph "Security Group Rules"
        INTERNET[Internet<br/>0.0.0.0/0:80] --> ALB_SG[ALB Security Group]
        ALB_SG --> ECS_SG[ECS Tasks Security Group]
        ECS_SG --> RDS_SG[RDS Security Group<br/>Port 5432]
        ECS_SG --> EFS_SG[EFS Security Group<br/>Port 2049]
    end
```

### High Availability Design

- **Multi-AZ Deployment**: Services distributed across availability zones
- **Auto Scaling**: 1-2 instances based on CPU (70%) and memory (80%)
- **Health Checks**: ALB monitors container health via `/health` endpoint
- **Automatic Recovery**: Failed tasks automatically replaced

## 💰 Cost Optimization

### AWS Free Tier Utilization

| Service | Free Tier Limit | Monthly Cost |
|---------|-----------------|--------------|
| **ECS Fargate** | - | $3-5 (ARM64) |
| **RDS PostgreSQL** | 750 hours | $0 |
| **S3 Storage** | 5GB | $0 |
| **EFS Storage** | 5GB | $0 |
| **ALB** | - | $16-20 |

**Total Estimated Cost**: $20-25/month

### Cost Optimization Features

- **ARM64 Architecture**: ~20% cost savings over x86_64
- **Burst Mode EFS**: Cost-effective storage with performance bursting
- **Minimal Resource Allocation**: Optimized for 2-3 concurrent users
- **Auto Scaling**: Resources scale with actual demand
- **Dynamic DAG Loading**: Reduces deployment costs

## 🔒 Security Model

### Principle of Least Privilege

```
ECS Execution Role
├── Read from AWS Secrets Manager ✓
└── Pull container images from ECR ✓

ECS Task Role  
├── Access EFS file system ✓
└── Read from Secrets Manager ✓

IAM User (for S3)
├── s3:GetObject on specific bucket ✓
├── s3:ListBucket on specific bucket ✓
└── s3:GetBucketLocation ✓
```

### Security Features

- **No Hardcoded Credentials**: All secrets stored in AWS Secrets Manager
- **VPC Isolation**: Private networking with security group controls
- **Basic Authentication**: Nginx proxy with configurable credentials
- **Encrypted Storage**: RDS and EFS encryption at rest
- **IAM Roles**: Service-based access control

## 📊 Monitoring & Observability

### CloudWatch Integration

- **Log Groups**: `/ecs/dagster-ecs-fargate`
- **Metrics**: ECS service metrics, ALB metrics, auto scaling
- **Health Checks**: Continuous monitoring via load balancer

### Performance Characteristics

- **ALB → ECS**: < 1ms latency (same AZ)
- **ECS → RDS**: < 2ms latency (same VPC)
- **ECS → S3**: 5-20ms latency (regional service)
- **Fargate Network**: Up to 25 Gbps performance

## 🛠️ Infrastructure as Code

### OpenTofu Configuration

The infrastructure is fully defined using OpenTofu (Terraform alternative):

```
infrastructure/
├── main.tf              # Main configuration
├── vpc.tf              # VPC and networking
├── ecs.tf              # ECS cluster and services
├── rds.tf              # PostgreSQL database
├── s3.tf               # S3 storage bucket
├── service_discovery.tf # ECS service discovery
└── outputs.tf          # Infrastructure outputs
```

### Key Outputs

- `load_balancer_url`: Dagster web UI URL
- `s3_bucket_name`: Bucket for DAG storage
- `aws_access_key_id`: S3 access credentials (sensitive)
- `aws_secret_access_key`: S3 secret key (sensitive)

## 🚀 Deployment Architecture

### Container Startup Sequence

```mermaid
graph TD
    START[Container Start] --> AUTH[Setup Basic Auth]
    AUTH --> CREDS[Test AWS Credentials]
    CREDS --> S3TEST[Test S3 Bucket Access]
    S3TEST --> SYNC[Sync DAGs & Workspace from S3<br/>timeout 30s]
    SYNC --> PERMSYNC[Start Periodic Sync<br/>Every 10 minutes]
    PERMSYNC --> DAGSTER[Start Dagster Services]
    DAGSTER --> HEALTH[Health Check Endpoint<br/>/health]
    HEALTH --> READY[Service Ready]
    
    style SYNC fill:#e1f5fe
    style DAGSTER fill:#e8f5e8
    style READY fill:#c8e6c9
```

### Rolling Deployment Process

1. **Image Build**: New Docker image built and pushed to ECR
2. **ECS Deployment**: Service update triggers rolling deployment
3. **Health Checks**: New tasks must pass health checks
4. **Traffic Switching**: ALB gradually routes traffic to new tasks
5. **Zero Downtime**: Old tasks terminated only after new ones are healthy

## 📁 Project Structure

```
├── infrastructure/        # OpenTofu configuration files
├── docker/               # Docker configuration & scripts
│   ├── Dockerfile        # Multi-stage build (local + production)
│   ├── entrypoint.sh     # S3 sync & startup script
│   ├── supervisord.conf  # Process management
│   └── nginx.conf        # Reverse proxy configuration
├── dags/                 # Local DAG files (synced to S3)
├── scripts/              # Automation scripts
├── docs/                 # Architecture documentation
├── docker-compose.yml    # Local development environment
├── workspace.yaml        # Dagster workspace configuration
└── Makefile             # Command abstractions
```

This architecture provides a robust, cost-effective, and scalable foundation for data orchestration workloads with the flexibility to handle both development and production requirements.