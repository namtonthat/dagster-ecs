from dagster import AssetSelection, define_asset_job

sample_job = define_asset_job(
    name="sample_job",
    selection=AssetSelection.all(),
    description="Sample job that materializes all assets",
)
