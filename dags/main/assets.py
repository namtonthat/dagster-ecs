import pandas as pd
from dagster import asset


@asset
def sample_data() -> pd.DataFrame:
    """Generate sample data for demonstration."""
    return pd.DataFrame({"id": [1, 2, 3], "value": ["a", "b", "c"]})


@asset
def processed_data(sample_data: pd.DataFrame) -> pd.DataFrame:
    """Process the sample data."""
    processed = sample_data.copy()
    processed["processed"] = True
    return processed


sample_assets = [sample_data, processed_data]
