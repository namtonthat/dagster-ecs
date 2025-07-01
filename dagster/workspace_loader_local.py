"""
Dynamic workspace loader for local development.
This module scans the local dags/ directory and loads all valid Definitions objects.
"""

import importlib.util
import sys
from pathlib import Path

from dagster import Definitions


def find_definitions_in_file(file_path: Path) -> tuple[str, Definitions] | None:
    """Load a Python file and find the first Definitions object."""
    try:
        # Generate a unique module name based on the file path
        module_name = str(file_path).replace("/", ".").replace(".py", "").replace("-", "_")

        # Load the module dynamically
        spec = importlib.util.spec_from_file_location(module_name, file_path)
        if spec is None or spec.loader is None:
            return None

        module = importlib.util.module_from_spec(spec)
        sys.modules[module_name] = module
        spec.loader.exec_module(module)

        # Find the first Definitions object in the module
        for attr_name in dir(module):
            attr = getattr(module, attr_name)
            if isinstance(attr, Definitions):
                # Use the file path structure to create a meaningful location name
                relative_path = file_path.relative_to(dags_dir)
                location_name = str(relative_path).replace("/", "_").replace(".py", "").replace("-", "_")
                return (location_name, attr)

        return None
    except Exception as e:
        print(f"✗ Failed to load {file_path}: {str(e)}")
        return None


# Use local dags directory
dags_dir = Path(__file__).parent.parent / "dags"
if dags_dir.exists():
    # Create a dictionary to store all discovered definitions
    for dag_file in dags_dir.rglob("*.py"):
        # Skip __init__.py and other non-DAG files
        if dag_file.name == "__init__.py" or dag_file.name.startswith("_"):
            continue

        result = find_definitions_in_file(dag_file)
        if result:
            location_name, definitions = result
            # Export the definitions object with its location name
            globals()[location_name] = definitions
            print(f"✓ Loaded DAG: {location_name} from {dag_file}")
else:
    print(f"Warning: DAGs directory {dags_dir} does not exist")


# For debugging - list all loaded DAGs
def list_loaded_dags():
    """Return a list of all loaded DAG location names."""
    return [name for name in globals() if isinstance(globals().get(name), Definitions)]
