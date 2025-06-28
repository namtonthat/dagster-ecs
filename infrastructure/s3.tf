resource "aws_s3_bucket" "dagster" {
  bucket = "${local.name_prefix}-storage-${random_id.bucket_suffix.hex}"

  tags = local.tags
}

output "s3_bucket_name" {
  description = "S3 bucket name for Dagster storage"
  value       = aws_s3_bucket.dagster.bucket
}

resource "aws_s3_bucket_versioning" "dagster" {
  bucket = aws_s3_bucket.dagster.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "dagster" {
  bucket = aws_s3_bucket.dagster.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "dagster" {
  bucket = aws_s3_bucket.dagster.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}