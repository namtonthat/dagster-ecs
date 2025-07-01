# Deployment Guide & Operations

## Overview

This guide covers deployment processes, operational procedures, and maintenance tasks for the Dagster ECS Fargate deployment. The system supports both rapid DAG deployments (60 seconds) and full infrastructure deployments (5-10 minutes).

## Related Documentation

- **[Architecture Guide](./architecture.md)**: System design, infrastructure details, and technical specifications
- **[Development Guide](./development.md)**: Local development setup and DAG creation workflow

## Table of Contents

- [🚀 Deployment Types](#-deployment-types)
- [📋 Deployment Workflow](#-deployment-workflow)
- [🔧 Operations Guide](#-operations-guide)
- [🏗️ Local Development](#️-local-development)
- [🗄️ Database Operations](#️-database-operations)
- [📊 Cost Management](#-cost-management)
- [🔒 Security Operations](#-security-operations)
- [🚨 Incident Response](#-incident-response)
- [📈 Performance Optimization](#-performance-optimization)
- [🔄 Backup & Recovery](#-backup--recovery)

## 🚀 Deployment Types

### 1. DAG-Only Deployment (Fast Path)

For pipeline changes without infrastructure modifications:

```bash
# Deploy DAG files to S3 (no Docker rebuild)
make deploy-dags

# Deploy DAGs and restart ECS service
make deploy-all
```

**Timeline**: 60 seconds (S3 upload + container sync)

### 2. Full Infrastructure Deployment

For runtime, infrastructure, or Dockerfile changes:

```bash
# Build and deploy complete system
make build         # Build Docker image
make push          # Push to ECR  
make deploy        # Deploy to ECS
```

**Timeline**: 5-10 minutes (build + deploy)

## 📋 Deployment Workflow

### Initial Setup

1. **Infrastructure Provisioning**
   ```bash
   make infra-init    # Initialize OpenTofu backend
   make infra-plan    # Preview changes
   make infra-apply   # Create AWS resources
   ```

2. **First Deployment**
   ```bash
   make build         # Build Docker image
   make push          # Push to ECR
   make deploy-dags   # Deploy DAGs to S3
   make deploy-ecs    # Deploy containers to ECS
   ```

3. **Verify Deployment**
   ```bash
   make url           # Get Dagster web UI URL
   make ecs-logs      # Monitor container logs
   ```

### Deployment Decision Matrix

| Change Type | Commands | Deployment Time | When to Use |
|-------------|----------|-----------------|-------------|
| DAG files only | `make deploy-dags` | ~60 seconds | Pipeline logic, asset definitions |
| DAG + restart | `make deploy-all` | ~2 minutes | New DAGs, major changes |
| Runtime changes | `make build && make push && make deploy` | 5-10 minutes | Dockerfile, dependencies, config |

## 🔧 Operations Guide

### Monitoring Commands

| Command | Purpose | Output |
|---------|---------|--------|
| `make ecs-logs` | View application logs | Real-time container logs |
| `aws ecs describe-services --cluster dagster-ecs-fargate-cluster --services dagster-ecs-fargate-service` | Check service status | JSON with task counts, deployments |
| `aws cloudwatch get-metric-statistics` | Monitor resources | CPU/memory metrics |

### Scaling Operations

```bash
# Scale up services manually
aws ecs update-service --cluster dagster-ecs-fargate-cluster --service dagster-ecs-fargate-service --desired-count 2

# Scale down (cost saving)
aws ecs update-service --cluster dagster-ecs-fargate-cluster --service dagster-ecs-fargate-service --desired-count 0
```

### Troubleshooting Guide

| Issue | Symptoms | Resolution |
|-------|----------|------------|
| **Container Won't Start** | ECS task stops immediately | 1. Check `make ecs-logs` for errors<br>2. Verify environment variables<br>3. Check AWS credentials<br>4. Test database connectivity |
| **DAG Sync Failures** | DAGs not appearing in UI | 1. Run `aws s3 ls` to test access<br>2. Check sync logs: `make ecs-logs \| grep sync`<br>3. Force restart: `make deploy` |
| **Health Check Failures** | ECS task unhealthy | 1. Check ECS task status<br>2. Test endpoint: `curl http://<task-ip>:3000/health`<br>3. Review security groups |

## 🏗️ Local Development

See the [Development Guide](./development.md) for local development setup and workflow.

## 🗄️ Database Operations

### Database Management

```bash
# Check database status
aws rds describe-db-instances --db-instance-identifier dagster-ecs-db

# Database backups are automated (7-day retention)
# Dagster handles schema migrations automatically
```

For database architecture details, see the [Architecture Guide](./architecture.md#infrastructure-specifications).

## 📊 Cost Management

### Quick Cost Controls

| Action | Command | Savings |
|--------|---------|----------|
| Stop ECS services | `aws ecs update-service --cluster dagster-ecs-fargate-cluster --service [service-name] --desired-count 0` | ~$5-10/month per service |
| Monitor usage | `aws ce get-cost-and-usage --time-period Start=YYYY-MM-DD,End=YYYY-MM-DD --granularity MONTHLY --metrics BlendedCost` | Identify cost trends |
| Scale down RDS | Modify instance type to `db.t3.micro` | ~$10-20/month |

For detailed cost analysis, see the [Architecture Guide](./architecture.md#-cost-optimization).

## 🔒 Security Operations

### Authentication Management

```bash
# Generate new basic auth credentials
make auth-generate user=admin pass=newpassword

# Deploy new credentials
make auth-deploy user=admin pass=newpassword

# Show current configuration
make auth-show
```

### Credential Rotation

```bash
# Rotate S3 access keys
# 1. Generate new keys in AWS Console
# 2. Update Secrets Manager
aws secretsmanager update-secret --secret-id dagster-ecs-aws-credentials --secret-string '{"AWS_ACCESS_KEY_ID":"new-key","AWS_SECRET_ACCESS_KEY":"new-secret"}'

# 3. Restart ECS services
make deploy
```

### Security Auditing

```bash
# Check IAM permissions
aws iam get-role-policy --role-name dagster-ecs-ecs-task-fargate --policy-name S3Access

# Review security groups
aws ec2 describe-security-groups --group-ids sg-xxxxxxxxx
```

## 🚨 Incident Response

### Incident Response Matrix

| Incident | Detection | Immediate Actions | Resolution Steps |
|----------|-----------|-------------------|------------------|
| **Service Down** | UI unreachable | 1. Check `make ecs-logs`<br>2. Verify task status | 1. Get task public IP<br>2. Check security groups<br>3. Force redeploy |
| **Database Error** | Connection failures in logs | 1. Check RDS status<br>2. Test connectivity | 1. Verify credentials<br>2. Check network ACLs<br>3. Review RDS logs |
| **S3 Sync Failed** | DAGs not updating | 1. Test S3 access<br>2. Check IAM policies | 1. Verify bucket permissions<br>2. Validate credentials<br>3. Manual sync test |

### Emergency Procedures

**Rollback Deployment:**
```bash
# Rollback to previous task definition
aws ecs update-service --cluster dagster-ecs-fargate-cluster --service dagster-ecs-fargate-service --task-definition dagster-ecs-webserver-fargate:previous-revision
```

**Scale Down for Maintenance:**
```bash
# Stop all services
make stop-production  # Custom command to set desired-count to 0
```

**Emergency Access:**
```bash
# Connect to running container (if needed)
aws ecs execute-command --cluster dagster-ecs-fargate-cluster --task task-id --command "/bin/bash" --interactive
```

## 📈 Performance Optimization

### Monitoring Metrics

Key metrics to monitor:
- **ECS CPU Utilization**: Target < 70%
- **ECS Memory Utilization**: Target < 80%
- **Direct Response Time**: No proxy overhead
- **Database Connections**: Monitor active connections
- **S3 Sync Duration**: Should complete < 30 seconds

### Performance Tuning

| Resource | Current | Scale Up Options | Impact |
|----------|---------|------------------|--------|
| CPU | 256 (0.25 vCPU) | 512, 1024, 2048 | Better concurrent processing |
| Memory | 512 MB | 1024, 2048, 4096 MB | More DAGs in memory |
| Task Count | 1 | 2-3 | Higher availability |

To scale: Edit `infrastructure/ecs_fargate.tf`, then run `make infra-apply && make deploy`.

## 🔄 Backup & Recovery

### Automated Backups

- **RDS**: 7-day automated backups enabled
- **S3**: Versioning enabled for DAG files
- **Infrastructure**: OpenTofu state stored remotely

### Manual Backup Procedures

```bash
# Backup DAG files
aws s3 sync s3://your-bucket-name/dags/ ./backup/dags/

# Backup database (if needed)
aws rds create-db-snapshot --db-instance-identifier dagster-ecs-db --db-snapshot-identifier manual-backup-$(date +%Y%m%d)
```

### Recovery Procedures

```bash
# Restore DAG files
aws s3 sync ./backup/dags/ s3://your-bucket-name/dags/

# Restore infrastructure from code
make infra-apply
```

## Next Steps

- Review the [Architecture Guide](./architecture.md) for system design details
- Set up local development using the [Development Guide](./development.md)
- Monitor costs using the strategies outlined in this guide

This deployment guide provides comprehensive coverage of operational procedures, from routine deployments to emergency response, ensuring reliable and efficient management of your Dagster ECS infrastructure.