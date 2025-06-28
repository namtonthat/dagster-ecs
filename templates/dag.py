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
def template_output_data(
    template_processed_data: dict[str, Any],
) -> AssetMaterialization:
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
