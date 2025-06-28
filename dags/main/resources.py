import os

from dagster_aws.s3 import S3Resource
from pydantic import Field


class S3PrefixResource(S3Resource):
    """S3 resource with automatic prefix isolation for repositories."""

    repository_prefix: str = Field(
        default="", description="Repository-specific prefix for S3 keys"
    )

    def _get_full_key(self, key: str) -> str:
        """Get full S3 key with repository prefix."""
        if self.repository_prefix:
            return f"{self.repository_prefix.rstrip('/')}/{key.lstrip('/')}"
        return key

    def upload_file(self, local_path: str, s3_key: str) -> str:
        """Upload file to S3 with repository prefix."""
        full_key = self._get_full_key(s3_key)
        bucket_obj = self.get_client().Bucket(self.bucket)
        bucket_obj.upload_file(local_path, full_key)
        return f"s3://{self.bucket}/{full_key}"

    def download_file(self, s3_key: str, local_path: str) -> str:
        """Download file from S3 with repository prefix."""
        full_key = self._get_full_key(s3_key)
        bucket_obj = self.get_client().Bucket(self.bucket)
        bucket_obj.download_file(full_key, local_path)
        return local_path

    def get_url(self, s3_key: str) -> str:
        """Get S3 URL for a key with repository prefix."""
        full_key = self._get_full_key(s3_key)
        return f"s3://{self.bucket}/{full_key}"

    def list_objects(self, prefix: str = "") -> list[dict]:
        """List objects with repository prefix."""
        full_prefix = self._get_full_key(prefix)
        bucket_obj = self.get_client().Bucket(self.bucket)

        objects = []
        for obj in bucket_obj.objects.filter(Prefix=full_prefix):
            # Remove repository prefix from returned keys
            key = obj.key
            if self.repository_prefix:
                key = key.replace(f"{self.repository_prefix}/", "", 1)
            objects.append(
                {
                    "Key": key,
                    "FullKey": obj.key,
                    "LastModified": obj.last_modified,
                    "Size": obj.size,
                    "ETag": obj.e_tag,
                }
            )

        return objects


def get_repository_resources(repository_name: str | None = None) -> dict:
    """Get resources configured for a specific repository using Dagster AWS resources."""

    # Get repository prefix from environment or use repository name
    repository_prefix = os.getenv("DAGSTER_S3_PREFIX")
    if not repository_prefix and repository_name:
        repository_prefix = f"repos/{repository_name}"

    # Get S3 bucket name from environment
    bucket_name = os.getenv("DAGSTER_S3_BUCKET", "dagster-dev-storage")

    return {
        "s3": S3PrefixResource(
            bucket=bucket_name,
            repository_prefix=repository_prefix or "",
            region_name=os.getenv("AWS_DEFAULT_REGION", "ap-southeast-2"),
        )
    }
