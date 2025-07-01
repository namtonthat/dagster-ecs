#!/usr/bin/env python3
"""
Test script to verify dynamic DAG loading works correctly.
"""

import sys
from pathlib import Path

# Add the parent directory to Python path so we can import dagster module
sys.path.insert(0, str(Path(__file__).parent.parent))

# Mock the /app/dags path to use local dags directory
from dagster import workspace_loader

workspace_loader.dags_dir = Path(__file__).parent.parent / "dags"

# Re-run the discovery process with local path
print("Discovering DAGs in local directory...")
print(f"Looking in: {workspace_loader.dags_dir}")
print("-" * 60)

# Clear any previously loaded DAGs
for key in list(workspace_loader.__dict__.keys()):
    if isinstance(workspace_loader.__dict__.get(key), workspace_loader.Definitions):
        del workspace_loader.__dict__[key]

# Re-discover DAGs
if workspace_loader.dags_dir.exists():
    for dag_file in workspace_loader.dags_dir.rglob("*.py"):
        if dag_file.name == "__init__.py" or dag_file.name.startswith("_"):
            continue

        result = workspace_loader.find_definitions_in_file(dag_file)
        if result:
            location_name, definitions = result
            setattr(workspace_loader, location_name, definitions)
            print(f"✓ Loaded DAG: {location_name}")
            print(f"  File: {dag_file}")
            print(f"  Assets: {[asset.key for asset in definitions.assets]}")
            print()

# List all loaded DAGs
loaded_dags = workspace_loader.list_loaded_dags()
print("-" * 60)
print(f"Total DAGs loaded: {len(loaded_dags)}")
print(f"DAG names: {loaded_dags}")
