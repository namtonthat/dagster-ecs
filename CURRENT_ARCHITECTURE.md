# Dagster ECS Fargate - Current Deployed Architecture

## Overview

This document describes the actual deployed architecture of the Dagster ECS Fargate deployment as it exists in AWS ap-southeast-2 region.

## High-Level Architecture

```mermaid
graph TB
    subgraph "Internet"
        U[Users/Developers]
    end
    
    subgraph "AWS ap-southeast-2"
        subgraph "VPC: 10.0.0.0/16"
            subgraph "Public Subnet A: 10.0.1.0/24 (ap-southeast-2a)"
                ALB[Application Load Balancer<br/>dagster-ecs-alb]
                NAT1[NAT Gateway]
                EFS1[EFS Mount Target]
                TASK1[ECS Fargate Task<br/>Webserver]
            end
            
            subgraph "Public Subnet B: 10.0.2.0/24 (ap-southeast-2b)"
                EFS2[EFS Mount Target]
                TASK2[ECS Fargate Task<br/>Daemon]
                RDS[(PostgreSQL RDS<br/>db.t3.micro)]
            end
            
            subgraph "ECS Fargate Cluster"
                subgraph "Webserver Service"
                    WS[Dagster Webserver<br/>Port 80]
                    NGINX[Nginx Proxy<br/>Basic Auth]
                end
                
                subgraph "Daemon Service"
                    DS[Dagster Daemon<br/>Scheduler]
                end
            end
            
            subgraph "Storage Services"
                EFS[EFS File System<br/>fs-036fd6909b5febdc7<br/>DAG Storage]
                S3[S3 Bucket<br/>ntonthat-dagster-ecs<br/>Assets & Logs]
            end
            
            subgraph "Security & Secrets"
                SM[AWS Secrets Manager<br/>Database Credentials]
                IAM[IAM Roles & Policies<br/>Task & Execution Roles]
            end
        end
        
        ECR[ECR Repository<br/>110386608476.dkr.ecr.ap-southeast-2.amazonaws.com/dagster-ecs<br/>ARM64 Images]
        CW[CloudWatch Logs<br/>/ecs/dagster-ecs-fargate]
    end
    
    U --> ALB
    ALB --> WS
    WS --> RDS
    WS --> S3
    WS --> EFS
    DS --> RDS
    DS --> S3
    DS --> EFS
    
    TASK1 --> ECR
    TASK2 --> ECR
    WS --> CW
    DS --> CW
    
    WS --> SM
    DS --> SM
```

## Component Details

### Networking Infrastructure
- **VPC**: `vpc-03a6c5433c1e0bb48` (10.0.0.0/16)
- **Internet Gateway**: `igw-0d1c64c4101d8855d`
- **Public Subnets**:
  - Subnet A: `subnet-07be55adc4fc6f661` (ap-southeast-2a)
  - Subnet B: `subnet-07dc946e2edb6096e` (ap-southeast-2b)

### Load Balancing
- **Application Load Balancer**: `dagster-ecs-alb-1680764756.ap-southeast-2.elb.amazonaws.com`
- **Target Group**: `dagster-ecs-tg` (Health check: `/health`)
- **Listener**: Port 80 HTTP → Forward to ECS Tasks

### ECS Fargate Services
- **Cluster**: `dagster-ecs-fargate-cluster`
- **Services Running**: 2 active services
  - **Webserver Service**: `dagster-ecs-fargate-service`
    - Task Definition: `dagster-ecs-webserver-fargate:4`
    - Desired Count: 1
    - Connected to ALB Target Group
  - **Daemon Service**: `dagster-ecs-daemon-service`
    - Task Definition: `dagster-ecs-daemon-fargate:1`
    - Desired Count: 1
    - Background scheduler

### Container Specifications
- **Architecture**: ARM64 (Fargate ARM)
- **CPU**: 256 units (0.25 vCPU)
- **Memory**: 512 MB
- **Image**: `110386608476.dkr.ecr.ap-southeast-2.amazonaws.com/dagster-ecs:latest`
- **Runtime Platform**: Linux ARM64

### Database
- **Engine**: PostgreSQL 15.13
- **Instance**: `db.t3.micro` (Free Tier)
- **Identifier**: `dagster-ecs-db`
- **Status**: Available
- **VPC**: Same as ECS (`vpc-03a6c5433c1e0bb48`)
- **Availability Zone**: ap-southeast-2a

### Storage
- **EFS File System**: `fs-036fd6909b5febdc7`
  - Mount Targets in both AZs
  - Used for DAG file synchronization
- **S3 Bucket**: `ntonthat-dagster-ecs`
  - DAG source files in `/dags/` prefix
  - Asset storage and logs

### Security & IAM
- **Task Execution Role**: `dagster-ecs-ecs-task-execution-fargate`
- **Task Role**: `dagster-ecs-ecs-task-fargate`
- **S3 User**: `dagster-ecs-s3-user`
- **Secrets Manager**: `dagster-ecs-aws-credentials`

## Auto Scaling Configuration

```mermaid
graph LR
    subgraph "Auto Scaling Policies"
        CPU[CPU Scaling<br/>Target: 70%]
        MEM[Memory Scaling<br/>Target: 80%]
    end
    
    subgraph "Scaling Targets"
        MIN[Min Capacity: 1]
        MAX[Max Capacity: 2]
        CUR[Current: 1]
    end
    
    CPU --> MIN
    MEM --> MIN
    MIN --> MAX
```

## Network Security Groups

```mermaid
graph TB
    subgraph "Security Groups"
        ALB_SG[ALB Security Group<br/>sg-08acb6a9856bbdba4]
        ECS_SG[ECS Tasks Security Group<br/>sg-0bb020c9aee2b8574]
        RDS_SG[RDS Security Group<br/>sg-0d2c9e0ba555ea279]
        EFS_SG[EFS Security Group<br/>sg-0386d3de14469acd2]
    end
    
    subgraph "Traffic Flow"
        INTERNET[Internet<br/>0.0.0.0/0:80] --> ALB_SG
        ALB_SG --> ECS_SG
        ECS_SG --> RDS_SG
        ECS_SG --> EFS_SG
    end
```

## Deployment Process Flow

```mermaid
sequenceDiagram
    participant Dev as Developer
    participant ECR as ECR Repository
    participant ECS as ECS Service
    participant ALB as Load Balancer
    participant S3 as S3 Bucket
    participant RDS as PostgreSQL
    
    Dev->>ECR: 1. Push ARM64 Docker Image
    Note over ECR: Image: dagster-ecs:latest<br/>Architecture: ARM64
    
    Dev->>ECS: 2. Force New Deployment
    ECS->>ECR: 3. Pull Latest Image
    ECS->>ECS: 4. Start New Task
    
    Note over ECS: Container Startup Process:
    ECS->>S3: 5a. Sync DAGs from S3
    ECS->>RDS: 5b. Connect to Database
    ECS->>ECS: 5c. Start Dagster Services
    
    ECS->>ALB: 6. Register with Target Group
    ALB->>ECS: 7. Health Check (/health)
    ECS-->>ALB: 8. HTTP 200 OK
    
    Note over ALB: Target becomes healthy
    ALB->>ECS: 9. Route Traffic
```

## Container Startup Sequence

```mermaid
graph TD
    START[Container Start] --> AUTH[Setup Basic Auth]
    AUTH --> CREDS[Test AWS Credentials]
    CREDS --> S3TEST[Test S3 Bucket Access]
    S3TEST --> SYNC[Sync DAGs from S3<br/>timeout 30s]
    SYNC --> PERMSYNC[Start Periodic Sync<br/>Every 60s]
    PERMSYNC --> DAGSTER[Start Dagster Services]
    DAGSTER --> HEALTH[Health Check Endpoint<br/>/health]
    HEALTH --> READY[Service Ready]
    
    style SYNC fill:#e1f5fe
    style DAGSTER fill:#e8f5e8
    style READY fill:#c8e6c9
```

## Resource Utilization

### Current Deployment Scale
- **ECS Tasks**: 2 running (1 webserver, 1 daemon)
- **Load Balancer Targets**: 1 healthy
- **Database Connections**: Active PostgreSQL connection
- **Storage**: EFS mounted, S3 sync active

### Cost Optimization Features
- **ARM64 Architecture**: ~20% cost savings vs x86_64
- **Fargate Spot**: Not currently enabled
- **Auto Scaling**: Scales 1-2 instances based on demand
- **Free Tier Usage**: 
  - RDS db.t3.micro (750 hours/month)
  - ECS Fargate (limited free tier)

## Access & Security

### Public Endpoints
- **Dagster Web UI**: http://dagster-ecs-alb-1680764756.ap-southeast-2.elb.amazonaws.com
- **Authentication**: Basic Auth (admin user)

### Private Resources
- **Database**: Private subnets, security group restricted
- **EFS**: VPC-only access via mount targets
- **S3**: IAM role-based access only

## Monitoring & Logging

### CloudWatch Integration
- **Log Groups**: `/ecs/dagster-ecs-fargate`
- **Metrics**: ECS service metrics, ALB metrics
- **Auto Scaling**: CPU and Memory based policies

### Health Monitoring
- **ALB Health Checks**: `/health` endpoint every 30s
- **ECS Service Health**: Task replacement on failures
- **Target Group**: Automatic deregistration/registration