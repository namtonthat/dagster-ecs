# Dagster ECS Fargate Deployment

Modern data orchestration platform deployed on AWS ECS Fargate with EFS storage for scalable, serverless data pipeline management.

## Architecture

### Infrastructure Components

- **ECS Fargate**: Serverless container orchestration for auto-scaling Dagster services
- **EFS**: Elastic File System for persistent DAG storage across containers
- **PostgreSQL**: Metadata storage for Dagster state and run history
- **ECR**: Container registry for Dagster application images
- **S3**: Object storage with prefix-based isolation per repository

### DAG Organization

```
dags/
├── main/           # Main repository DAGs
├── repo-2/         # Additional repository DAGs
└── repo-n/         # Each repo gets its own namespace
```

Each repository gets isolated S3 prefixes: `repos/{repo-name}/`

## Quick Start

### Prerequisites

- Docker and Docker Compose
- uv (Python package manager)
- Python 3.12+

### Local Development

1. **Clone and setup**:

   ```bash
   git clone <repo-url>
   cd dagster-ecs
   uv sync
   ```

2. **Start local environment**:

   ```bash
   docker-compose up -d
   ```

3. **Access Dagster UI**:
   Open <http://localhost:3000>

### Development Workflow

1. **Create new DAG**:

   ```bash
   cp dags/main/template_dag.py dags/main/my_new_dag.py
   # Edit the DAG with your logic
   ```

2. **Test locally**:

   ```bash
   # Lint and format
   uv run ruff check dags/
   uv run ruff format dags/
   
   # Type check
   uv run ty check dags/
   
   # Run tests
   uv run pytest dags/ -v
   ```

3. **Verify in Dagster UI**:
   - Check that your DAG appears in the UI
   - Test asset materialization
   - Verify S3 prefix isolation

4. **Deploy**:

   ```bash
   git add .
   git commit -m "Add new DAG: my_new_dag"
   git push origin main
   ```

   The CI/CD pipeline will automatically deploy to AWS ECS.

## Writing DAGs

### Template DAG Structure

Use the template in `dags/main/template_dag.py`:

```python
from dagster import AssetMaterialization, asset, job
from dags.main.resources import get_repository_resources

# Replace 'template' with your DAG name
REPOSITORY_NAME = "template"

@asset(key_prefix=f"repos/{REPOSITORY_NAME}")
def template_data_asset():
    """Template data processing asset.
    
    Replace this with your actual data processing logic.
    """
    # Your data processing logic here
    return {"processed_records": 100}

@job(name=f"{REPOSITORY_NAME}_pipeline")
def template_pipeline():
    """Template pipeline job."""
    template_data_asset()

# Repository definition
defs = get_repository_resources(
    repository_name=REPOSITORY_NAME,
    assets=[template_data_asset],
    jobs=[template_pipeline],
)
```

### Creating a New DAG

1. **Copy template**:

   ```bash
   cp dags/main/template_dag.py dags/main/my_pipeline.py
   ```

2. **Update the DAG**:
   - Change `REPOSITORY_NAME = "my_pipeline"`
   - Rename functions (e.g., `my_pipeline_data_asset`)
   - Implement your data processing logic
   - Update docstrings and comments

3. **Register in workspace**:
   Add to `workspace.yaml`:

   ```yaml
   load_from:
     - python_module: dags.main.my_pipeline
   ```

### S3 Integration

All assets automatically get S3 prefix isolation:

- Repository `main` → S3 prefix `repos/main/`
- Repository `analytics` → S3 prefix `repos/analytics/`

The S3PrefixResource handles this automatically - just use standard Dagster S3 operations.

## Testing Strategy

### Local Testing

```bash
# Lint and format
uv run ruff check dags/
uv run ruff format dags/

# Type checking
uv run ty check dags/

# Unit tests
uv run pytest dags/ -v

# Integration tests (requires Docker)
docker-compose up -d
# Test DAGs in Dagster UI at http://localhost:3000
```

### Pre-deployment Checklist

- [ ] DAG appears in local Dagster UI
- [ ] All assets materialize successfully
- [ ] S3 operations use correct prefix
- [ ] No linting or type errors
- [ ] Tests pass

## Deployment

### CI/CD Pipeline

The GitHub Actions workflow automatically:

1. Runs linting and type checking
2. Builds Docker image
3. Pushes to ECR
4. Deploys to ECS Fargate

### Manual Deployment

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

## Environment Variables

### Local Development

Set in `docker-compose.yml`:

- `DAGSTER_POSTGRES_*`: Database connection
- `DAGSTER_HOME`: Dagster configuration directory

### Production (ECS)

Set in task definition:

- `DAGSTER_POSTGRES_*`: RDS connection details
- `AWS_DEFAULT_REGION`: ap-southeast-2
- `S3_BUCKET`: Dagster storage bucket

## Template DAG

Create new DAGs by copying and modifying this template:

```python
"""
Template DAG for Dagster ECS deployment.
Copy this file and replace 'template' with your DAG name throughout.
"""

from typing import Any

from dagster import AssetMaterialization, asset, job
from dags.main.resources import get_repository_resources

# TODO: Replace 'template' with your DAG name
REPOSITORY_NAME = "template"


@asset(key_prefix=f"repos/{REPOSITORY_NAME}")
def template_input_data() -> dict[str, Any]:
    """Load input data for processing.
    
    TODO: Replace with your data loading logic.
    """
    # Example: Load from database, API, or file
    return {
        "records": [
            {"id": 1, "value": "data1"},
            {"id": 2, "value": "data2"},
        ]
    }


@asset(key_prefix=f"repos/{REPOSITORY_NAME}")
def template_processed_data(template_input_data: dict[str, Any]) -> dict[str, Any]:
    """Process the input data.
    
    TODO: Replace with your data processing logic.
    """
    records = template_input_data["records"]
    
    # Example processing
    processed = [
        {**record, "processed": True, "length": len(record["value"])}
        for record in records
    ]
    
    return {"processed_records": processed}


@asset(key_prefix=f"repos/{REPOSITORY_NAME}")
def template_output_data(template_processed_data: dict[str, Any]) -> AssetMaterialization:
    """Save processed data to storage.
    
    TODO: Replace with your data saving logic.
    """
    processed_records = template_processed_data["processed_records"]
    
    # Example: Save to S3, database, or API
    # The S3 operations will automatically use the correct prefix
    output_path = f"output/processed_data_{len(processed_records)}_records.json"
    
    return AssetMaterialization(
        asset_key=f"repos/{REPOSITORY_NAME}/output_data",
        description=f"Processed {len(processed_records)} records",
        metadata={
            "records_count": len(processed_records),
            "output_path": output_path,
        },
    )


@job(name=f"{REPOSITORY_NAME}_pipeline")
def template_pipeline():
    """Main pipeline for template processing.
    
    TODO: Update job name and add your pipeline logic.
    """
    input_data = template_input_data()
    processed_data = template_processed_data(input_data)
    template_output_data(processed_data)


# Repository definition - connects assets and jobs
defs = get_repository_resources(
    repository_name=REPOSITORY_NAME,
    assets=[template_input_data, template_processed_data, template_output_data],
    jobs=[template_pipeline],
)
```

To use this template:

1. Copy to a new file: `cp dags/main/template_dag.py dags/main/your_dag_name.py`
2. Replace all instances of `template` with your DAG name
3. Implement your specific data processing logic
4. Update the workspace.yaml to include your new module
5. Test locally before deploying

## Support

For issues or questions:

- Check the Dagster documentation: <https://docs.dagster.io/>
- Review logs: `docker-compose logs dagster`
- Monitor ECS service in AWS Console

