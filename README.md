# Dagster ECS Fargate Deployment

[![Deploy to AWS ECS](https://github.com/namtonthat/dagster-ecs/workflows/Deploy%20to%20AWS%20ECS/badge.svg)](https://github.com/namtonthat/dagster-ecs/actions)
[![Python](https://img.shields.io/badge/python-3.12+-blue.svg)](https://www.python.org/downloads/)
[![Ruff](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/astral-sh/ruff/main/assets/badge/v2.json)](https://github.com/astral-sh/ruff)
[![OpenTofu](https://img.shields.io/badge/OpenTofu-1.6+-purple.svg)](https://opentofu.org/)
[![Dagster](https://img.shields.io/badge/Dagster-1.8+-orange.svg)](https://dagster.io/)
[![AWS ECS](https://img.shields.io/badge/AWS-ECS%20Fargate-orange.svg)](https://aws.amazon.com/ecs/)

Modern data orchestration platform deployed on AWS ECS Fargate with **dynamic DAG loading** for rapid deployment and scalable, serverless data pipeline management.

## 🚀 Current Deployment Status

**✅ OPERATIONAL**: Fully deployed and running in AWS ap-southeast-2
- **Web UI**: Direct access via ECS task public IP on port 3000
- **Authentication**: Basic auth enabled (admin user)
- **Services**: 2 ECS Fargate services (webserver + daemon)
- **Auto Scaling**: 1-2 instances based on CPU/Memory
- **Architecture**: ARM64 containers for cost optimization

## 📚 Documentation

- **[🏠 Development Guide](./docs/development.md)** - Local setup, development workflow, and available commands
- **[📋 Architecture Guide](./docs/architecture.md)** - Complete system architecture, infrastructure, and dynamic DAG loading
- **[🚀 Deployment Guide](./docs/deployment.md)** - Deployment processes, operations, and troubleshooting

## 🏗️ Key Features

- **Dynamic DAG Discovery**: Automatically discovers all DAGs in `/app/dags/` - no manual configuration needed
- **Dynamic S3 Loading**: DAG changes deploy in 60 seconds without container rebuilds
- **Cost Optimized**: ARM64 + AWS Free Tier (~$20-25/month)
- **Production Ready**: Auto-scaling, high availability, comprehensive monitoring
- **Developer Friendly**: Local development environment mirrors production exactly

## 🚀 Quick Start

### Prerequisites
- Docker and Docker Compose
- `uv` (Python package manager)
- Python 3.12+

### Local Setup

```bash
git clone <repo-url>
cd dagster-ecs
make install    # Install Python dependencies
make start      # Start local Dagster stack
```

Access Dagster UI at: http://localhost:3000

### Available Commands

```bash
make help    # Show all available commands
```

📖 **For detailed setup, development workflow, and deployment procedures, see the [Documentation](#-documentation) section above.**

## 💬 Support

For issues or questions:

- Check the Dagster documentation: <https://docs.dagster.io/>
- Review logs: `docker-compose logs dagster`
- Monitor ECS service in AWS Console
