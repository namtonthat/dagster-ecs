# EFS Deployment Guide for Teams

This guide explains how teams can deploy their Dagster DAGs using GitHub Actions to EFS with automatic S3 backups.

## Overview

The deployment architecture uses:
- **GitHub Actions**: Directly mounts EFS and deploys DAGs
- **EFS**: Primary storage for all DAG code (mounted by Dagster containers)
- **S3**: Backup storage for reference and disaster recovery

## Architecture

```
GitHub Repository → GitHub Actions → EFS Mount → Deploy DAGs
                                        ↓
                                    S3 Backup
                                        ↓
                                 Dagster Containers
                                 (Read from EFS)
```

## Prerequisites

1. AWS infrastructure deployed (`make infra-apply`)
2. GitHub repository with Actions enabled
3. AWS IAM role configured for GitHub Actions

## Initial Setup (One-time)

### 1. Configure GitHub Actions Access

Run the setup script to create the necessary IAM role:

```bash
# Set your GitHub organization and repository
export GITHUB_ORG="your-org"
export GITHUB_REPO="dagster-ecs"

# Run the setup script
./scripts/setup-github-efs-access.sh
```

This creates an IAM role with permissions to:
- Mount EFS
- Write to S3 backup bucket
- Read SSM parameters
- Restart ECS services

### 2. Add GitHub Secret

Add the IAM role ARN as a GitHub secret:

1. Go to `https://github.com/YOUR_ORG/YOUR_REPO/settings/secrets/actions`
2. Click "New repository secret"
3. Name: `AWS_DEPLOY_ROLE_ARN`
4. Value: The role ARN output from the setup script

## Team DAG Structure

Teams should organize their DAGs as follows:

```
dags/
├── team-analytics/
│   ├── definitions.py      # Main Dagster definitions
│   ├── assets/
│   │   ├── __init__.py
│   │   └── raw_data.py
│   ├── jobs/
│   │   ├── __init__.py
│   │   └── daily_pipeline.py
│   └── schedules/
│       └── daily_schedule.py
└── team-ml/
    ├── definitions.py
    └── ...
```

### Example definitions.py

```python
from dagster import Definitions, load_assets_from_modules
from . import assets, jobs, schedules

defs = Definitions(
    assets=load_assets_from_modules([assets]),
    jobs=[
        jobs.daily_pipeline.daily_job,
    ],
    schedules=[
        schedules.daily_schedule.daily_schedule,
    ]
)
```

## Deployment Process

### Automatic Deployment (On Push)

Any push to the `main` branch that modifies files in `dags/` will trigger automatic deployment:

```bash
git add dags/team-analytics/
git commit -m "Update analytics pipeline"
git push origin main
```

### Manual Deployment

To manually deploy a specific team's DAGs:

1. Go to Actions tab in GitHub
2. Select "Deploy DAGs to EFS and S3"
3. Click "Run workflow"
4. Enter team name (optional)
5. Click "Run workflow"

### What Happens During Deployment

1. **GitHub Actions Runner**:
   - Assumes the IAM role
   - Installs EFS utilities
   - Gets EFS ID from SSM Parameter Store

2. **EFS Mount**:
   - Mounts EFS to `/mnt/efs`
   - Creates workspace structure if needed

3. **DAG Deployment**:
   - Copies team DAGs to `/mnt/efs/dagster-workspace/projects/TEAM_NAME/`
   - Preserves directory structure
   - Sets proper permissions

4. **S3 Backup**:
   - Syncs entire workspace to S3
   - Creates deployment metadata
   - Maintains version history

5. **Service Restart**:
   - Forces ECS service redeployment
   - Dagster picks up new DAGs

## Accessing Deployed DAGs

### View in S3 (Backup)

```bash
# List all backed up DAGs
aws s3 ls s3://your-dagster-bucket-dags-backup/dagster-workspace/projects/

# Download a specific team's DAGs
aws s3 sync s3://your-dagster-bucket-dags-backup/dagster-workspace/projects/team-analytics/ ./backup/
```

### View Deployment History

```bash
# Get latest deployment metadata
aws s3 cp s3://your-dagster-bucket-dags-backup/dagster-workspace/metadata/latest-deployment.json -

# Output:
{
  "deployment_time": "2024-01-15T10:30:00Z",
  "git_sha": "abc123...",
  "git_ref": "refs/heads/main",
  "deployed_by": "github-user",
  "teams_deployed": "team-analytics team-ml"
}
```

## Workspace Configuration

The workspace configuration is automatically managed:

```yaml
# /mnt/efs/dagster-workspace/workspace.yaml
load_from:
  - python_file: /opt/dagster/workspace/projects/team-analytics/definitions.py
  - python_file: /opt/dagster/workspace/projects/team-ml/definitions.py
```

## Monitoring Deployments

### GitHub Actions Summary

Each deployment creates a summary with:
- EFS ID used
- S3 backup location
- Teams deployed
- Deployment timestamp
- First 20 files in S3 backup

### CloudWatch Logs

Monitor ECS tasks for DAG loading issues:

```bash
# View Dagster webserver logs
aws logs tail /ecs/dagster-webserver --follow

# View Dagster daemon logs
aws logs tail /ecs/dagster-daemon --follow
```

## Troubleshooting

### DAGs Not Appearing

1. Check GitHub Actions logs for deployment errors
2. Verify files exist in S3 backup
3. Check ECS service logs for import errors
4. Ensure `definitions.py` exports a `defs` object

### Permission Errors

1. Verify IAM role has correct permissions
2. Check security group allows EFS access
3. Ensure file ownership is set to UID 1000

### Import Errors

1. Check Python dependencies are available
2. Verify relative imports are correct
3. Ensure all `__init__.py` files exist

## Best Practices

1. **Test Locally First**:
   ```bash
   cd dags/team-analytics
   dagster dev -f definitions.py
   ```

2. **Use Version Control**:
   - Tag releases
   - Use meaningful commit messages
   - Document changes

3. **Monitor S3 Costs**:
   - Old versions auto-expire after 30 days
   - Files transition to IA storage after 7 days

4. **Keep DAGs Lightweight**:
   - Don't include large data files
   - Use `.gitignore` for local artifacts

## Cost Optimization

- **EFS**: ~$0.30/GB/month (burst mode)
- **S3 Backup**: ~$0.023/GB/month (IA after 7 days)
- **GitHub Actions**: Free for public repos, minutes included for private
- **Total**: < $1/month for typical usage

## Security Considerations

1. **OIDC Authentication**: No long-lived AWS credentials
2. **Least Privilege**: IAM role has minimal required permissions
3. **Encryption**: EFS and S3 data encrypted at rest
4. **Network Isolation**: EFS only accessible within VPC