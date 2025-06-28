# Dagster ECS Fargate Deployment

[![Python](https://img.shields.io/badge/python-3.12+-blue.svg)](https://www.python.org/downloads/)
[![Ruff](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/astral-sh/ruff/main/assets/badge/v2.json)](https://github.com/astral-sh/ruff)
[![OpenTofu](https://img.shields.io/badge/OpenTofu-1.6+-purple.svg)](https://opentofu.org/)
[![Dagster](https://img.shields.io/badge/Dagster-1.8+-orange.svg)](https://dagster.io/)
[![AWS ECS](https://img.shields.io/badge/AWS-ECS%20Fargate-orange.svg)](https://aws.amazon.com/ecs/)

Modern data orchestration platform deployed on AWS ECS Fargate with EFS storage for scalable, serverless data pipeline management.

## 🏗️ Architecture

### ☁️ Infrastructure Components

- **ECS Fargate**: Serverless container orchestration for auto-scaling Dagster services
- **EFS**: Elastic File System for persistent DAG storage across containers
- **PostgreSQL**: Metadata storage for Dagster state and run history
- **ECR**: Container registry for Dagster application images
- **S3**: Object storage with prefix-based isolation per repository

### 📁 DAG Organisation

```
dags/
├── main/           # Main repository DAGs
│   ├── template_dag.py    # Template for creating new DAGs
│   └── resources.py       # S3 prefix isolation resources
├── external_repos/        # External repository DAGs (managed via make commands)
└── tests/                 # DAG tests
```

Each repository gets isolated S3 prefixes: `repos/{repo-name}/`

## 🚀 Quick Start

### 📋 Prerequisites

- Docker and Docker Compose
- uv (Python package manager)
- Python 3.12+

### 💻 Local Development

1. **Clone and setup**:

   ```bash
   git clone <repo-url>
   cd dagster-ecs
   make install  # Installs Python dependencies with uv
   ```

2. **Start local environment**:

   ```bash
   make dev  # Starts local Dagster stack
   ```

3. **Access Dagster UI**:
   Open <http://localhost:3000>

### 🔄 Development Workflow

1. **Create new DAG**:

   ```bash
   make create name=my_new_dag
   # Edit the generated DAG with your logic
   ```

2. **Test locally**:

   ```bash
   make test  # Runs type checking, linting, and tests
   ```

3. **Verify in Dagster UI**:
   - Check that your DAG appears in the UI
   - Test asset materialisation
   - Verify S3 prefix isolation

4. **Deploy**:

   ```bash
   git add .
   git commit -m "Add new DAG: my_new_dag"
   git push origin main
   ```

   The CI/CD pipeline will automatically deploy to AWS ECS.

## ✍️ Writing DAGs

### 📝 DAG Creation

Create new DAGs using the Makefile command:

```bash
make create name=my_pipeline
```

This automatically:
- Copies the template DAG
- Replaces all template references with your DAG name
- Creates `dags/main/my_pipeline_dag.py`

### 🔧 Customizing Your DAG

After creating a new DAG:

1. **Implement your logic** in the generated file
2. **Update asset functions** with your data processing
3. **Test locally** with `make test`
4. **Verify in Dagster UI** at http://localhost:3000

### 🗄️ S3 Integration

All assets automatically get S3 prefix isolation:

- Repository `main` → S3 prefix `repos/main/`
- Repository `analytics` → S3 prefix `repos/analytics/`

The S3PrefixResource handles this automatically - just use standard Dagster S3 operations.

## 🧪 Testing Strategy

### 🏠 Local Testing

```bash
# Run all tests (type checking, linting, pytest)
make test

# Start local development environment
make dev

# Test DAGs in Dagster UI at http://localhost:3000
```

### ✅ Pre-deployment Checklist

- [ ] DAG appears in local Dagster UI
- [ ] All assets materialise successfully
- [ ] S3 operations use correct prefix
- [ ] No linting or type errors
- [ ] Tests pass

## 🚢 Deployment

### 🔄 CI/CD Pipeline

The GitHub Actions workflow automatically:

1. Runs linting and type checking
2. Builds Docker image
3. Pushes to ECR
4. Deploys to ECS Fargate

### 🛠️ Manual Deployment

```bash
# Build and push image
docker build -f docker/Dockerfile -t dagster-app .
docker tag dagster-app:latest <ecr-repo-url>:latest
docker push <ecr-repo-url>:latest

# Update ECS service
aws ecs update-service \
  --cluster dagster-ecs-fargate-cluster \
  --service dagster-ecs-service-fargate \
  --force-new-deployment
```

## 🌍 Environment Variables

### 🏠 Local Development

Set in `docker-compose.yml`:

- `DAGSTER_POSTGRES_*`: Database connection
- `DAGSTER_HOME`: Dagster configuration directory

### ☁️ Production (ECS)

Set in task definition:

- `DAGSTER_POSTGRES_*`: RDS connection details
- `AWS_DEFAULT_REGION`: ap-southeast-2
- `S3_BUCKET`: Dagster storage bucket


## 💬 Support

For issues or questions:

- Check the Dagster documentation: <https://docs.dagster.io/>
- Review logs: `docker-compose logs dagster`
- Monitor ECS service in AWS Console

