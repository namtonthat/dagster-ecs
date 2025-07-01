#!/usr/bin/env python3
"""
Test script to verify dynamic DAG loading works correctly.
"""

import sys
from pathlib import Path

# Add the parent directory to Python path so we can import dagster module
sys.path.insert(0, str(Path(__file__).parent.parent))

# Test the workspace loader with local directory
from dagster_config.workspace_loader import load_assets_from_file

dags_dir = Path(__file__).parent.parent / "dags"

print("Discovering DAGs in local directory...")
print(f"Looking in: {dags_dir}")
print("-" * 60)

all_assets = []
loaded_files = []

if dags_dir.exists():
    for dag_file in sorted(dags_dir.rglob("*.py")):
        # Skip __init__.py and other non-DAG files
        if dag_file.name == "__init__.py" or dag_file.name.startswith("_"):
            continue

        assets = load_assets_from_file(dag_file)
        if assets:
            all_assets.extend(assets)
            loaded_files.append(dag_file)
            print(f"✓ Loaded {len(assets)} assets from {dag_file.relative_to(dags_dir)}")
            print(f"  Asset keys: {[asset.key for asset in assets]}")
            print()

print("-" * 60)
print(f"Total files processed: {len(loaded_files)}")
print(f"Total assets loaded: {len(all_assets)}")
print(f"Loaded files: {[f.name for f in loaded_files]}")
