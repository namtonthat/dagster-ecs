# Dagster ECS - Detailed Network Architecture

## Network Topology

```mermaid
graph TB
    subgraph "Internet Gateway"
        IGW[igw-0d1c64c4101d8855d<br/>Internet Gateway]
    end
    
    subgraph "VPC: vpc-03a6c5433c1e0bb48 (10.0.0.0/16)"
        subgraph "Availability Zone A (ap-southeast-2a)"
            subgraph "Public Subnet A: subnet-07be55adc4fc6f661"
                ALB_A[ALB Node A<br/>10.0.1.x]
                EFS_MT_A[EFS Mount Target<br/>fsmt-0700b3e1fae07001d<br/>10.0.1.194]
                ECS_TASK_A[ECS Task<br/>10.0.1.101<br/>Current Active]
            end
        end
        
        subgraph "Availability Zone B (ap-southeast-2b)"
            subgraph "Public Subnet B: subnet-07dc946e2edb6096e"
                ALB_B[ALB Node B<br/>10.0.2.x]
                EFS_MT_B[EFS Mount Target<br/>fsmt-0e1563cb103d33525<br/>10.0.2.202]
                RDS_INST[PostgreSQL RDS<br/>dagster-ecs-db<br/>10.0.2.x:5432]
            end
        end
        
        subgraph "Route Table: rtb-0da0a9d12f16fa191"
            RT[Default Route<br/>0.0.0.0/0 → IGW]
        end
    end
    
    subgraph "External Services"
        ALB_DNS[dagster-ecs-alb-1680764756<br/>.ap-southeast-2.elb.amazonaws.com]
        S3_BUCKET[s3://ntonthat-dagster-ecs]
        ECR_REPO[110386608476.dkr.ecr<br/>.ap-southeast-2.amazonaws.com]
    end
    
    IGW --> ALB_A
    IGW --> ALB_B
    ALB_DNS --> ALB_A
    ALB_DNS --> ALB_B
    ALB_A --> ECS_TASK_A
    ALB_B --> ECS_TASK_A
    
    ECS_TASK_A --> EFS_MT_A
    ECS_TASK_A --> EFS_MT_B
    ECS_TASK_A --> RDS_INST
    ECS_TASK_A --> S3_BUCKET
    ECS_TASK_A --> ECR_REPO
```

## Security Group Rules

### ALB Security Group (sg-08acb6a9856bbdba4)
```mermaid
graph LR
    subgraph "Inbound Rules"
        HTTP[HTTP Port 80<br/>Source: 0.0.0.0/0]
    end
    
    subgraph "Outbound Rules"
        ECS_OUT[HTTP Port 80<br/>Target: ECS Tasks SG]
    end
    
    HTTP --> ALB_SG[ALB Security Group]
    ALB_SG --> ECS_OUT
```

### ECS Tasks Security Group (sg-0bb020c9aee2b8574)
```mermaid
graph LR
    subgraph "Inbound Rules"
        ALB_IN[HTTP Port 80<br/>Source: ALB SG]
    end
    
    subgraph "Outbound Rules"
        HTTPS_OUT[HTTPS 443<br/>Dest: 0.0.0.0/0]
        HTTP_OUT[HTTP 80<br/>Dest: 0.0.0.0/0]
        POSTGRES_OUT[PostgreSQL 5432<br/>Dest: RDS SG]
        NFS_OUT[NFS 2049<br/>Dest: EFS SG]
    end
    
    ALB_IN --> ECS_SG[ECS Tasks Security Group]
    ECS_SG --> HTTPS_OUT
    ECS_SG --> HTTP_OUT
    ECS_SG --> POSTGRES_OUT
    ECS_SG --> NFS_OUT
```

### RDS Security Group (sg-0d2c9e0ba555ea279)
```mermaid
graph LR
    subgraph "Inbound Rules"
        PG_IN[PostgreSQL 5432<br/>Source: ECS Tasks SG]
    end
    
    PG_IN --> RDS_SG[RDS Security Group]
```

### EFS Security Group (sg-0386d3de14469acd2)
```mermaid
graph LR
    subgraph "Inbound Rules"
        NFS_IN[NFS 2049<br/>Source: ECS Tasks SG]
    end
    
    NFS_IN --> EFS_SG[EFS Security Group]
```

## Traffic Flow Patterns

### User Request Flow
```mermaid
sequenceDiagram
    participant User
    participant Route53 as DNS/Route53
    participant ALB as Application Load Balancer
    participant TG as Target Group
    participant ECS as ECS Task (Nginx)
    participant Dagster as Dagster Webserver
    
    User->>Route53: 1. DNS Lookup
    Route53-->>User: 2. ALB IP Address
    User->>ALB: 3. HTTP Request :80
    ALB->>TG: 4. Health Check
    TG-->>ALB: 5. Target Healthy
    ALB->>ECS: 6. Forward Request :80
    ECS->>ECS: 7. Basic Auth Check
    ECS->>Dagster: 8. Proxy to Dagster :3000
    Dagster-->>ECS: 9. Dagster Response
    ECS-->>ALB: 10. HTTP Response
    ALB-->>User: 11. Final Response
```

### Container Initialization Flow
```mermaid
sequenceDiagram
    participant ECS as ECS Service
    participant ECR as ECR Registry
    participant S3 as S3 Bucket
    participant EFS as EFS Mount
    participant RDS as PostgreSQL
    participant SM as Secrets Manager
    
    ECS->>ECR: 1. Pull ARM64 Image
    ECR-->>ECS: 2. Image Layers
    ECS->>ECS: 3. Start Container
    ECS->>SM: 4. Fetch DB Credentials
    SM-->>ECS: 5. Return Secrets
    ECS->>S3: 6. Sync DAG Files (timeout 30s)
    S3-->>ECS: 7. DAG Files Downloaded
    ECS->>EFS: 8. Mount EFS Volume
    EFS-->>ECS: 9. Mount Successful
    ECS->>RDS: 10. Test DB Connection
    RDS-->>ECS: 11. Connection OK
    ECS->>ECS: 12. Start Dagster Services
    ECS->>ECS: 13. Health Check Ready
```

## Network Performance Characteristics

### Latency Considerations
- **ALB → ECS**: < 1ms (same AZ preferred)
- **ECS → RDS**: < 2ms (same VPC)
- **ECS → EFS**: < 1ms (local mount targets)
- **ECS → S3**: 5-20ms (regional service)
- **User → ALB**: Varies by location

### Bandwidth Allocation
- **Fargate Task**: Up to 25 Gbps network performance
- **EFS Throughput**: Burst mode (up to 100 MiB/s)
- **RDS**: Up to 2,085 Mbps (t3.micro)
- **ALB**: Automatically scales

## High Availability Design

```mermaid
graph TB
    subgraph "Multi-AZ Deployment"
        subgraph "AZ-A"
            ALB_A[ALB Node A]
            EFS_A[EFS Mount A]
            TASK_A[ECS Task A<br/>Active]
        end
        
        subgraph "AZ-B"
            ALB_B[ALB Node B]
            EFS_B[EFS Mount B]
            RDS_B[(RDS Primary)]
            TASK_B[ECS Task B<br/>Standby]
        end
    end
    
    subgraph "Failover Scenarios"
        F1[AZ-A Failure<br/>→ Tasks migrate to AZ-B]
        F2[Task Failure<br/>→ ECS restarts task]
        F3[Health Check Fail<br/>→ ALB stops routing]
    end
    
    ALB_A -.-> ALB_B
    EFS_A -.-> EFS_B
    TASK_A -.-> TASK_B
```

## Container Networking Details

### Network Mode: awsvpc
- Each task gets its own ENI (Elastic Network Interface)
- Private IP assigned from subnet CIDR
- Direct VPC networking without port mapping
- Full security group integration

### DNS Resolution
- **VPC DNS**: Enabled (169.254.169.253)
- **Route53 Private Zones**: Available
- **Service Discovery**: AWS Cloud Map ready
- **Container DNS**: Inherit from VPC

### IP Allocation
```
VPC CIDR: 10.0.0.0/16 (65,536 IPs)
├── Subnet A: 10.0.1.0/24 (256 IPs)
│   ├── ALB: 10.0.1.x (2-3 IPs)
│   ├── EFS Mount: 10.0.1.194
│   ├── ECS Tasks: 10.0.1.101+
│   └── Available: ~250 IPs
└── Subnet B: 10.0.2.0/24 (256 IPs)
    ├── ALB: 10.0.2.x (2-3 IPs)
    ├── EFS Mount: 10.0.2.202
    ├── RDS: 10.0.2.x
    └── Available: ~250 IPs
```

## Monitoring Network Health

### CloudWatch Metrics
- **ALB Metrics**: Request count, latency, target health
- **ECS Metrics**: Network utilization, task health
- **VPC Flow Logs**: Available for troubleshooting

### Health Check Configuration
```yaml
Target Group Health Check:
  Protocol: HTTP
  Port: 80
  Path: /health
  Interval: 30 seconds
  Timeout: 5 seconds
  Healthy Threshold: 2
  Unhealthy Threshold: 2
```