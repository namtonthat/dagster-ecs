"""
Test DAG for Dynamic Loading
"""

from dagster import Definitions, asset


@asset
def dynamic_test_asset():
    """Test asset created to verify dynamic loading"""
    return {"message": "Dynamic loading works!", "timestamp": "2025-07-01"}


# Define the DAG (code location)
defs = Definitions(assets=[dynamic_test_asset])
