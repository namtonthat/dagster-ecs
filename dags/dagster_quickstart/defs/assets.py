from pathlib import Path

import dagster as dg
import pandas as pd

# Use relative paths from the working directory
base_path = Path("dags/dagster_quickstart/defs/data")
sample_data_file = base_path / "sample_data.csv"
processed_data_file = base_path / "processed_data.csv"

# Ensure the data directory exists
base_path.mkdir(parents=True, exist_ok=True)


@dg.asset
def sample_data():
    """Load sample data from CSV file or create it if it doesn't exist."""
    if not sample_data_file.exists():
        # Create sample data if it doesn't exist
        sample_df = pd.DataFrame(
            {
                "name": ["Alice", "Bob", "Charlie", "Diana", "Eve"],
                "age": [25, 35, 45, 28, 38],
                "city": ["New York", "San Francisco", "Chicago", "Miami", "Seattle"],
            }
        )
        sample_df.to_csv(sample_data_file, index=False)
        return f"Created sample data at {sample_data_file}"

    # Read existing data
    df = pd.read_csv(sample_data_file)
    return f"Loaded {len(df)} rows from {sample_data_file}"


@dg.asset(deps=[sample_data])
def processed_data():
    """Process the sample data by adding age groups."""
    # Read data from the CSV
    df = pd.read_csv(sample_data_file)

    # Add an age_group column based on the value of age
    df["age_group"] = pd.cut(df["age"], bins=[0, 30, 40, 100], labels=["Young", "Middle", "Senior"])

    # Save processed data
    df.to_csv(processed_data_file, index=False)
    return f"Processed {len(df)} rows and saved to {processed_data_file}"


# Define the Dagster definitions that will be loaded
defs = dg.Definitions(
    assets=[sample_data, processed_data],
)
