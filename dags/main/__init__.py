from dagster import Definitions

# Import using absolute imports to avoid relative import issues
from dags.main.assets import sample_assets
from dags.main.jobs import sample_job
from dags.main.resources import get_repository_resources

defs = Definitions(
    assets=sample_assets,
    jobs=[sample_job],
    resources=get_repository_resources("main"),
)
