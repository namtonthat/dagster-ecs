"""
Auto-discover all Dagster assets from the local dags directory.
This module is loaded directly by Dagster for local development.
Assets are organized into groups based on their folder structure.
"""

import importlib
import sys
from pathlib import Path

from dagster import AssetsDefinition, Definitions, load_assets_from_modules


def discover_and_group_assets():
    """Discover all assets and group them by folder."""
    # For local development, use relative path
    dags_dir = Path(__file__).parent.parent / "dags"

    # Add dags directory to Python path so we can import from it
    if str(dags_dir) not in sys.path:
        sys.path.insert(0, str(dags_dir))

    if not dags_dir.exists():
        print(f"Warning: {dags_dir} does not exist")
        return []

    print(f"Discovering modules in {dags_dir}...")

    # Group assets by their folder
    all_assets = []

    for py_file in sorted(dags_dir.rglob("*.py")):
        if py_file.name == "__init__.py" or py_file.name.startswith("_"):
            continue

        # Get the folder name for grouping
        relative_path = py_file.relative_to(dags_dir)
        # Use the first directory as the group name, or file name for root files
        group_name = relative_path.parts[0] if len(relative_path.parts) > 1 else relative_path.stem

        # Convert folder name to a nice group name
        # e.g., "team-marketing" -> "team_marketing"
        group_name = group_name.replace("-", "_")

        # Convert file path to module path
        module_path = str(relative_path.with_suffix("")).replace("/", ".")

        try:
            print(f"Loading module: {module_path}")
            module = importlib.import_module(module_path)

            # Load assets from the module
            module_assets = load_assets_from_modules([module])

            # Add group metadata to each asset
            for asset in module_assets:
                if isinstance(asset, AssetsDefinition):
                    # Create a mapping of asset keys to group names
                    group_names_by_key = {key: group_name for key in asset.keys}
                    grouped_asset = asset.with_attributes(group_names_by_key=group_names_by_key)
                    all_assets.append(grouped_asset)
                else:
                    all_assets.append(asset)

            print(f"✓ Loaded {len(module_assets)} assets from {module_path} into group '{group_name}'")

        except Exception as e:
            print(f"✗ Failed to load {module_path}: {e}")

    return all_assets


# Discover all assets with grouping
grouped_assets = discover_and_group_assets()

print(f"\nTotal assets loaded: {len(grouped_assets)}")

# Create the definitions
defs = Definitions(assets=grouped_assets)
