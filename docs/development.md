# Development Guide

This guide covers the development workflow for working with the Dagster ECS deployment.

## Quick Start

```bash
# Install dependencies
make install

# Start local development environment
make start

# View logs
make logs

# Stop when done
make stop
```

## Available Commands

All commands are available through the Makefile. Run `make help` to see the complete list of available commands with descriptions organized by category.

## 🔄 Development Workflow

### Creating New DAGs

1. **Generate from template**:
   ```bash
   make create dag=my_data_pipeline
   ```
   This creates `dags/main/my_data_pipeline_dag.py` from the template.

2. **Edit the generated file**:
   - Update asset definitions
   - Modify job configurations
   - Add your data processing logic

3. **Test locally**:
   ```bash
   make test                    # Run linting and type checking
   make start                   # Start local environment (if not running)
   # Visit http://localhost:3000 to verify DAG appears
   ```

### Fast DAG Deployment (Recommended)

For DAG-only changes (no Docker/infrastructure changes):

```bash
# Edit your DAG files directly
vim dags/main/assets.py

# Test locally first
make test

# Deploy to production (fast path)
make deploy-dags    # 60 second deployment
```

**How it works**: DAG files are uploaded to S3 and automatically synced to running containers every 10 minutes.

### Full Deployment (When Needed)

For runtime changes (Dockerfile, dependencies, configuration):

```bash
# Build new Docker image
make build

# Push to ECR
make push

# Deploy to ECS (triggers rolling update)
make deploy-ecs
```

**Timeline**: 5-10 minutes for complete deployment

## 🧪 Testing Strategy

### Local Testing Workflow

```bash
# Start development environment
make start

# Run comprehensive tests
make test              # Includes: ruff linting, mypy type checking, pytest

# Test in Dagster UI
# 1. Open http://localhost:3000
# 2. Navigate to your DAG
# 3. Materialize assets to test execution
# 4. Check logs for any errors
```

### Pre-deployment Checklist

- [ ] `make test` passes with no errors
- [ ] DAG appears in local Dagster UI (http://localhost:3000)
- [ ] Assets materialize successfully in local environment
- [ ] No linting or type errors
- [ ] S3 operations use correct prefixes (handled automatically)

## ⚡ Performance Tips

### Faster Development Cycles

1. **Use DAG-only deployment**: `make deploy-dags` (60s vs 5-10min)
2. **Keep local environment running**: Don't stop/start unnecessarily
3. **Test locally first**: Catch issues before deploying
4. **Use template generation**: `make create dag=name` for consistency

### Local Development Optimization

```bash
# Start with minimal services
make start

# View specific service logs
make logs | grep dagster-webserver

# Reset only when needed (preserves some cache)
make reset
```

## 🔧 Advanced Usage

Use `make help` to see all available commands including:
- Custom build targets
- Infrastructure management operations
- Debugging and monitoring commands
- Authentication management
- AWS information and deployment commands

## 🚨 Troubleshooting

### Common Issues

**Local environment won't start:**
```bash
make stop    # Stop all services
make reset   # Reset and restart
make logs    # Check for errors
```

**Tests failing:**
```bash
make test    # See specific failures
# Fix issues in your code
# Re-run tests until they pass
```

**DAG not appearing after deployment:**
```bash
make ecs-logs | grep sync    # Check S3 sync logs
make deploy-all              # Force container restart
```

**Authentication issues:**
```bash
make auth-show               # Check current config
make auth-deploy user=admin pass=newpassword
```

### Getting Help

```bash
make help    # Shows all available commands with descriptions
```

This development workflow is optimized for rapid iteration and reliable deployment of data pipelines.