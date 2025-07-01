# External Repository Setup Guide

This guide helps teams set up their own repositories to deploy Dagster projects to the centralized ECS instance.

## Repository Structure

Your repository should follow this structure:

```
your-team-repo/
├── .github/
│   └── workflows/
│       └── deploy.yml              # GitHub Actions workflow
├── your_team_name/                 # Python package (use underscores)
│   ├── __init__.py
│   ├── definitions.py              # Main Dagster definitions
│   └── assets/                     # Asset definitions
│       ├── __init__.py
│       ├── bronze_assets.py        # Raw data ingestion
│       ├── silver_assets.py        # Cleaned/transformed data
│       └── gold_assets.py          # Business-ready datasets
├── tests/                          # Unit tests
│   ├── __init__.py
│   └── test_assets.py
├── pyproject.toml                  # Project configuration
├── README.md                       # Documentation
└── .gitignore
```

## Step 1: Create Repository Structure

### 1.1 Initialize Project

```bash
# Create directory structure
mkdir -p your-team-repo/{your_team_name/assets,tests,.github/workflows}
cd your-team-repo

# Initialize git
git init
```

### 1.2 Create pyproject.toml

```toml
[build-system]
requires = ["setuptools>=64", "setuptools-scm>=8"]
build-backend = "setuptools.build_meta"

[project]
name = "your-team-dagster"
version = "0.1.0"
description = "Dagster project for Your Team"
readme = "README.md"
requires-python = ">=3.9"
dependencies = [
    "dagster>=1.5.0",
    "dagster-aws>=0.21.0",
    "pandas>=2.0.0",
    "boto3>=1.28.0",
]

[project.optional-dependencies]
dev = [
    "pytest>=7.0.0",
    "pytest-cov>=4.0.0",
    "ruff>=0.1.0",
    "mypy>=1.0.0",
    "types-boto3>=1.28.0",
]

[tool.setuptools.packages.find]
where = ["."]
include = ["your_team_name*"]

[tool.ruff]
line-length = 100
target-version = "py39"

[tool.mypy]
python_version = "3.9"
warn_return_any = true
warn_unused_configs = true
ignore_missing_imports = true

[tool.pytest.ini_options]
testpaths = ["tests"]
python_files = "test_*.py"
```

### 1.3 Create Package Structure

**your_team_name/__init__.py:**
```python
"""Your Team's Dagster project."""
```

**your_team_name/definitions.py:**
```python
"""Main Dagster definitions for Your Team."""

from dagster import Definitions, load_assets_from_modules

from . import assets

# Load all assets from the assets module
all_assets = load_assets_from_modules([assets])

# Define any jobs, schedules, sensors here
jobs = []
schedules = []
sensors = []

# Create the main Definitions object
defs = Definitions(
    assets=all_assets,
    jobs=jobs,
    schedules=schedules,
    sensors=sensors,
)
```

**your_team_name/assets/__init__.py:**
```python
"""Asset definitions for Your Team."""

from .bronze_assets import *  # noqa
from .silver_assets import *  # noqa
from .gold_assets import *  # noqa
```

## Step 2: Create Sample Assets

**your_team_name/assets/bronze_assets.py:**
```python
"""Bronze layer assets - raw data ingestion."""

from dagster import asset, AssetExecutionContext
import pandas as pd
import boto3


@asset(
    group_name="bronze",
    description="Raw customer data from source system",
    compute_kind="python",
    metadata={"owner": "data-team@company.com"},
)
def raw_customers(context: AssetExecutionContext) -> pd.DataFrame:
    """Load raw customer data."""
    context.log.info("Loading raw customer data")
    
    # Example: Load from S3
    # s3 = boto3.client('s3')
    # obj = s3.get_object(Bucket='data-bucket', Key='raw/customers.csv')
    # df = pd.read_csv(obj['Body'])
    
    # For demo, create sample data
    df = pd.DataFrame({
        'customer_id': [1, 2, 3, 4, 5],
        'name': ['Alice', 'Bob', 'Charlie', 'David', 'Eve'],
        'email': ['alice@example.com', 'bob@example.com', 'charlie@example.com', 
                  'david@example.com', 'eve@example.com'],
        'created_at': pd.date_range('2024-01-01', periods=5, freq='D')
    })
    
    context.log.info(f"Loaded {len(df)} customer records")
    return df
```

**your_team_name/assets/silver_assets.py:**
```python
"""Silver layer assets - cleaned and transformed data."""

from dagster import asset, AssetExecutionContext
import pandas as pd


@asset(
    deps=["raw_customers"],
    group_name="silver",
    description="Cleaned and validated customer data",
    compute_kind="python",
)
def cleaned_customers(context: AssetExecutionContext, raw_customers: pd.DataFrame) -> pd.DataFrame:
    """Clean and validate customer data."""
    context.log.info("Cleaning customer data")
    
    # Remove duplicates
    df = raw_customers.drop_duplicates(subset=['email'])
    
    # Standardize names
    df['name'] = df['name'].str.title()
    
    # Add data quality checks
    invalid_emails = df[~df['email'].str.contains('@')].shape[0]
    if invalid_emails > 0:
        context.log.warning(f"Found {invalid_emails} records with invalid emails")
    
    context.log.info(f"Cleaned data contains {len(df)} records")
    return df
```

**your_team_name/assets/gold_assets.py:**
```python
"""Gold layer assets - business-ready datasets."""

from dagster import asset, AssetExecutionContext
import pandas as pd


@asset(
    deps=["cleaned_customers"],
    group_name="gold",
    description="Customer metrics for business reporting",
    compute_kind="python",
)
def customer_metrics(context: AssetExecutionContext, cleaned_customers: pd.DataFrame) -> pd.DataFrame:
    """Calculate customer metrics."""
    context.log.info("Calculating customer metrics")
    
    # Example metrics
    metrics = cleaned_customers.groupby(
        pd.Grouper(key='created_at', freq='D')
    ).agg({
        'customer_id': 'count',
        'email': 'nunique'
    }).rename(columns={
        'customer_id': 'new_customers',
        'email': 'unique_emails'
    })
    
    metrics['cumulative_customers'] = metrics['new_customers'].cumsum()
    
    context.log.info(f"Generated metrics for {len(metrics)} days")
    return metrics
```

## Step 3: Add Tests

**tests/test_assets.py:**
```python
"""Tests for asset definitions."""

import pytest
import pandas as pd
from your_team_name.assets.bronze_assets import raw_customers
from your_team_name.assets.silver_assets import cleaned_customers


def test_raw_customers_loads():
    """Test that raw customers can be loaded."""
    # Create mock context
    from unittest.mock import Mock
    context = Mock()
    context.log = Mock()
    
    # Execute asset
    result = raw_customers(context)
    
    # Verify result
    assert isinstance(result, pd.DataFrame)
    assert len(result) > 0
    assert 'customer_id' in result.columns


def test_cleaned_customers_removes_duplicates():
    """Test that cleaning removes duplicates."""
    # Create test data with duplicates
    test_data = pd.DataFrame({
        'customer_id': [1, 2, 2],
        'name': ['alice', 'bob', 'bob'],
        'email': ['alice@test.com', 'bob@test.com', 'bob@test.com'],
        'created_at': pd.date_range('2024-01-01', periods=3)
    })
    
    # Create mock context
    from unittest.mock import Mock
    context = Mock()
    context.log = Mock()
    
    # Execute asset
    result = cleaned_customers(context, test_data)
    
    # Verify duplicates removed
    assert len(result) == 2
    assert result['email'].nunique() == 2
```

## Step 4: Configure GitHub Actions

Copy the workflow from `templates/external-repo-github-action.yml` to `.github/workflows/deploy.yml`.

## Step 5: Configure Repository Secrets

In your GitHub repository settings, add these secrets:

1. **DAGSTER_PROJECT_NAME**: Your project identifier (e.g., `team-marketing`)
2. **DAGSTER_AWS_ACCESS_KEY_ID**: AWS access key with permissions to mount EFS
3. **DAGSTER_AWS_SECRET_ACCESS_KEY**: AWS secret key
4. **AWS_REGION**: AWS region (e.g., `us-east-1`)
5. **DAGSTER_EFS_ID**: EFS file system ID (provided by central team)
6. **DAGSTER_EFS_ACCESS_POINT_ID**: EFS access point ID (optional, for enhanced security)

## Step 6: Local Development

### Install dependencies:
```bash
pip install -e ".[dev]"
```

### Run tests:
```bash
pytest tests/ -v
ruff check .
mypy .
```

### Test Dagster locally:
```bash
dagster dev -m your_team_name.definitions
```

## Step 7: Deploy

Push to main branch to trigger deployment:
```bash
git add .
git commit -m "Initial Dagster project setup"
git push origin main
```

## Best Practices

1. **Naming Conventions**:
   - Use descriptive asset names
   - Group related assets
   - Prefix with your team name if needed

2. **Asset Dependencies**:
   - Use `deps` parameter for upstream dependencies
   - Keep dependency chains reasonable (< 5 levels)

3. **Metadata**:
   - Add owner information
   - Document data sources
   - Include business context

4. **Testing**:
   - Test each asset individually
   - Mock external dependencies
   - Validate data quality

5. **Performance**:
   - Partition large datasets
   - Use incremental processing
   - Cache intermediate results

6. **Security**:
   - Never commit credentials
   - Use AWS IAM roles when possible
   - Validate input data

## Troubleshooting

### Assets not appearing in UI
1. Check GitHub Actions logs for deployment errors
2. Verify workspace.yaml was updated
3. Wait 2-3 minutes for refresh
4. Check ECS logs for import errors

### Import errors
1. Ensure all dependencies are in pyproject.toml
2. Check for circular imports
3. Verify module structure matches workspace config

### Permission denied
1. Verify AWS credentials are correct
2. Check IAM permissions for EFS
3. Ensure project name matches configuration

## Support

For issues or questions:
1. Check ECS logs for detailed errors
2. Review this guide and examples
3. Contact the central data platform team
4. Open an issue in the main dagster-ecs repository