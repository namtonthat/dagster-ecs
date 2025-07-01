"""
Dynamic workspace loader for local development.
This module scans the local dags/ directory and loads all assets into a single Definitions object.
"""

import importlib.util
import sys
from pathlib import Path
from typing import Any

from dagster import AssetKey, Definitions


def load_assets_from_file(file_path: Path, base_dir: Path) -> list[Any]:
    """Load all assets from a Python file."""
    try:
        # Generate a unique module name based on the file path
        module_name = str(file_path).replace("/", ".").replace(".py", "").replace("-", "_")

        # Load the module dynamically
        spec = importlib.util.spec_from_file_location(module_name, file_path)
        if spec is None or spec.loader is None:
            return []

        module = importlib.util.module_from_spec(spec)
        sys.modules[module_name] = module
        spec.loader.exec_module(module)

        # Find all assets in the module
        assets = []
        for attr_name in dir(module):
            attr = getattr(module, attr_name)
            # Check if it's a Definitions object
            if hasattr(attr, "_assets") and hasattr(attr, "__class__") and attr.__class__.__name__ == "Definitions":
                # Extract assets from the Definitions object
                assets.extend(attr.assets)
            # Also check for direct asset definitions
            elif hasattr(attr, "key") and isinstance(getattr(attr, "key", None), AssetKey):
                assets.append(attr)

        if assets:
            relative_path = file_path.relative_to(base_dir)
            print(f"✓ Loaded {len(assets)} assets from {relative_path}")

        return assets
    except Exception as e:
        print(f"✗ Failed to load {file_path}: {str(e)}")
        return []


# Use local dags directory
dags_dir = Path(__file__).parent.parent / "dags"
all_assets = []

if dags_dir.exists():
    print(f"Discovering DAGs in {dags_dir}...")
    for dag_file in sorted(dags_dir.rglob("*.py")):
        # Skip __init__.py and other non-DAG files
        if dag_file.name == "__init__.py" or dag_file.name.startswith("_"):
            continue

        assets = load_assets_from_file(dag_file, dags_dir)
        all_assets.extend(assets)

    print(f"Total assets discovered: {len(all_assets)}")
else:
    print(f"Warning: DAGs directory {dags_dir} does not exist")

# Create a single Definitions object with all discovered assets
defs = Definitions(assets=all_assets)
